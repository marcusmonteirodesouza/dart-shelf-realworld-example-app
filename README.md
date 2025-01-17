# ![RealWorld Example App](logo.png)

> ### [Dart](https://dart.dev) codebase containing real world examples (CRUD, auth, advanced patterns, etc) that adheres to the [RealWorld](https://github.com/gothinkster/realworld) spec and API.


### [Demo](https://demo.realworld.io/)&nbsp;&nbsp;&nbsp;&nbsp;[RealWorld](https://github.com/gothinkster/realworld)

This codebase was created to demonstrate a fully fledged backend application built with **[Dart](https://github.com/dart-lang/shelf)** including CRUD operations, authentication, routing, pagination, and more.

We've gone to great lengths to adhere to the **[Dart](https://dart.dev/community)** community styleguides & best practices.

For more information on how to this works with other frontends/backends, head over to the [RealWorld](https://github.com/gothinkster/realworld) repo.


# How it works

This is a [monolithic application](https://docs.microsoft.com/en-us/dotnet/architecture/containerized-lifecycle/design-develop-containerized-apps/monolithic-applications) [structured by components](https://github.com/goldbergyoni/nodebestpractices/blob/master/sections/projectstructre/breakintcomponents.md). It uses:

* [PostgreSQL](https://www.postgresql.org/) as the database, and uses some of it's specific features such as [Arrays](https://www.postgresql.org/docs/current/arrays.html).
* [SQL](https://en.wikipedia.org/wiki/SQL) instead of an [ORM](https://en.wikipedia.org/wiki/Object%E2%80%93relational_mapping). See for [example](lib/src/articles/articles_service.dart).
* [Docker Compose](https://docs.docker.com/compose/) to run tests and the application locally. For the testing strategy, I opted to not use mocks and the such to unit test individual functions: instead, I applied a [honeycomb testing strategy](https://www.oreilly.com/library/view/hands-on-microservices/9781789133608/7c9f1260-b0c5-4416-816f-1cad140b56dd.xhtml) to run the tests against the actual app connected with an actual database. I felt that this:
  * Gave me more confidence that the application is working correctly.
  * Allowed me to refactor more easily as I test only the public interface and not the implementation details. This [talk by Dan Abramov](https://www.deconstructconf.com/2019/dan-abramov-the-wet-codebase), for example, illustrates very well the importance of this.
* [Github Actions](https://docs.github.com/en/actions) to run tests on Pull Requests and Merges to the `master` branch. 

# Getting started

Install the [Dart SDK](https://dart.dev/get-dart).

## Running the App

### Define the environment variables

Create a [`.env`](https://github.com/mockturtl/dotenv) file according to the [template](.env.template).

### Run the app

```bash
$ ./dev.sh
```

## Running the tests

### Run the test script

```
$ ./test.sh
```

## Deployment

### Deploy to [Google Cloud Platform](https://cloud.google.com/) (GCP)

1. [Install terraform](https://www.terraform.io/).
1. [Install the gcloud CLI](https://cloud.google.com/sdk/docs/install).
1. [Login with gcloud](https://cloud.google.com/sdk/gcloud/reference/auth/login).
1. Go to the [dev bootstrap directory](./deploy/gcp/terraform/environments/dev/bootstrap), change the `locals.tf` values to your own and run `terraform apply`.
1. Go the [scripts directory](./deploy/gcp/scripts) and run `build-and-push-container-image.sh <YOUR_PROJECT_ID> <YOUR_ARTIFACT_REPOSITORY>`.
1. Go to the [dev directory](./deploy/gcp/terraform/environments/dev), change the `locals.tf` values to your own and run `terraform apply`.
