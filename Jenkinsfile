// @Library('github.com/base2Services/ciinabox-pipelines') _
pipeline {
  agent any
  environment {
    JAVA_HOME='/root/.sdkman/candidates/java/current'
  }
  stages {
    stage('Build') {
      steps {
        sh './mvnw clean install -DskipTests'
      }
    }
    stage('Package') {
      steps {
        echo 'build and push docker to ecr'
      }
    }
    stage('Deploy') {
      steps {
        echo "cloudformation deploy using IAM role"
      }
    }
  }
}