// @Library(['github.com/base2Services/ciinabox-pipelines']) _
library identifier: 'ciinabox@master',
    retriever: modernSCM([
      $class: 'GitSCMSource',
      remote: 'https://github.com/base2Services/ciinabox-pipelines.git'
    ])
pipeline {
  agent any
  stages {
    stage('Build') {
      agent {
        docker {
          image 'adoptopenjdk:11-jdk-hotspot'
        }
      }
      steps {
        sh './mvnw clean install'
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