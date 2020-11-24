library identifier: 'ciinabox@master',
    retriever: modernSCM([
      $class: 'GitSCMSource',
      remote: 'https://github.com/base2Services/ciinabox-pipelines.git'
    ])
pipeline {
  agent any
  environment {
    AWS_ACCOUNT='006077743195'
    AWS_REGION='us-east-1'
    IMAGE_NAME='aaronwalker/greeter'
  }
  stages {
    stage('Build') {
      steps {
        script {
            echo "${gitopsPRManager}"
        }
        sh './mvnw clean install'
      }
    }
    stage('Package') {
      steps {
        echo 'build and push docker to ecr'
        dockerBuild repo: "${env.AWS_ACCOUNT}.dkr.ecr.${env.AWS_REGION}.amazonaws.com",
          image: env.IMAGE_NAME,
          tags: ["${env.BUILD_NUMBER}"],
          dockerfile: 'src/main/docker/Dockerfile.jvm',
          push: false,
          cleanup: true
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
        echo "cfcompile greeter -q --validate"
        echo "cfpublish greeter@${env.BUILD_NUMBER}"
      }
    }
  }
}
