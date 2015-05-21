## Configuring shipit.yml

All the settings in `shipit.yml` are totally optional. Most applications can be deployed without any configuration.

The `shipit.yml` file has X main sections:

review
  checklist
  monitoring
fetch
deploy
rollback

tasks
  restart
  unlock

dependencies
  bundler

### review

<code>review.checklist</code>

Array of strings. Can contain and HTML tags. Users are required to check each of them before being able to deploy.


<code>review.monitoring</code>

List of inclusions. Inclusions can either be of type image or iframe:

```
review:
  monitoring:
    - image: https://example.com/monitoring.png
    - iframe: https://example.com/monitoring.html
```


### fetch

<code>fetch</code>

Array of shell commands, shipit will execute them regularly to check the deployed revision.

foo # command to run to get the revision of the currently-deployed version, defaults to disabled

curl --silent https://app.shopify.com/services/ping/version

### deploy

<code>deploy.override</code>

Array of shell commands required to deploy the application. Shipit will try to infer it from the repository structure, but you can change the default inference.

exec ./script/multi_deploy.rb bundle exec cap $ENVIRONMENT deploy

### rollback

<code>rollback.override</code>

Array of shell commands required to rollback the application to a previous state. Shipit will try to infer it from the repository structure, but you can change the default inference.

- foo # command(s) to run for rollbacks, defaults to disabled unless capistrano is detected

exec ./script/multi_deploy.rb bundle exec cap $ENVIRONMENT deploy:rollback


### Custom tasks

You can define a custom list of commands that Shipit users will be able to trigger for your application:

<code>tasks.restart</code>

```
tasks:
  restart:
```

    Restarts application. Sometimes needed if you want unicorns and resques to reboot but don't want to ship any new code.

    cap $ENVIRONMENT deploy:restart



<code>tasks.unlock</code>

    Unlocks Capistrano. Sometimes needed if a deployment failed badly and deploys are still locked.

    cap $ENVIRONMENT deploy:unlock



### Dependencies


<code>dependencies</code>

```
dependencies:
  bundler:
    without:
      - default
      - production
      - development
      - test
      - staging
      - benchmark
      - debug
      - assets
      - stagingdb
```

### ???

<code>machine.environment</code>
    key: val # things added as environment variables
```
