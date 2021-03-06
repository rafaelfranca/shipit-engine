class Task < ActiveRecord::Base
  belongs_to :user
  belongs_to :stack, touch: true, counter_cache: true
  belongs_to :until_commit, class_name: 'Commit'
  belongs_to :since_commit, class_name: 'Commit'

  has_many :chunks, -> { order(:id) }, class_name: 'OutputChunk', dependent: :destroy

  serialize :definition, TaskDefinition

  scope :success,   -> { where(status: 'success') }
  scope :completed, -> { where(status: %w(success error failed)) }
  scope :active,    -> { where(status: %w(pending running)) }

  scope :due_for_rollup, -> { completed.where(rolled_up: false).where('created_at <= ?', 1.hour.ago) }

  after_commit :emit_hooks

  state_machine :status, initial: :pending do
    event :run do
      transition pending: :running
    end

    event :failure do
      transition running: :failed
    end

    event :complete do
      transition running: :success
    end

    event :error do
      transition all => :error
    end

    state :pending
    state :running
    state :failed
    state :success
    state :error
  end

  delegate :acquire_git_cache_lock, to: :stack

  def spec
    @spec ||= DeploySpec::FileSystem.new(working_directory, stack.environment)
  end

  def enqueue
    raise "only persisted jobs can be enqueued" unless persisted?
    PerformTaskJob.perform_later(task_id: id, stack_id: stack_id)
  end

  def write(text)
    chunks.create!(text: text)
  end

  def chunk_output
    if rolled_up?
      output
    else
      chunks.pluck(:text).join
    end
  end

  def schedule_rollup_chunks
    ChunkRollupJob.perform_later(self)
  end

  def rollup_chunks
    ActiveRecord::Base.transaction do
      self.output = chunk_output
      chunks.delete_all
      update_attribute(:rolled_up, true)
    end
  end

  def output
    gzip = self[:gzip_output]

    if gzip.nil? || gzip.empty?
      ''
    else
      ActiveSupport::Gzip.decompress(gzip)
    end
  end

  def output=(string)
    self[:gzip_output] = ActiveSupport::Gzip.compress(string)
  end

  def rollback?
    false
  end

  def rollbackable?
    false
  end

  def author
    user || AnonymousUser.new
  end

  def finished?
    !pending? && !running?
  end

  def pid
    Rails.cache.read("task:#{id}:pid")
  end

  def pid=(pid)
    Rails.cache.write("task:#{id}:pid", pid, expires_in: 1.hour)
  end

  def abort!
    target_pid = pid
    return write("Abort: failed, PID unknown\n") unless target_pid.present?

    write("Abort: sending SIGTERM to pid #{target_pid}\n")
    Process.kill('TERM', target_pid)
  rescue Errno::ESRCH
    write("Abort: PID #{target_pid} ESRCH: No such process\n")
    true
  end

  def working_directory
    File.join(stack.deploys_path, id.to_s)
  end

  def clear_working_directory
    FileUtils.rm_rf(working_directory)
  end

  def emit_hooks
    return unless previous_changes.include?('status')
    Hook.emit(hook_event, stack, hook_event => self, status: status, stack: stack)
  end

  def hook_event
    self.class.name.underscore.to_sym
  end
end
