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
        sh 'docker build -f src/main/docker/Dockerfile.jvm -t aaronwalker/greeter .'
      }
    }
    stage('Deploy') {
      agent {
        docker {
          image 'theonestack/cfhighlander'
        }
      }
      steps {
        echo "cloudformation deploy using IAM role"
        echo "cfhighlander -v"
      }
    }
  }
}