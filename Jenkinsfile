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
            sh 'printenv | sort'
            script {
                echo "creds:${gitopsPRManager.credentialId}"
                echo "PR:${gitopsPRManager.currentPrFlowRequest.number}"
            }
        }
      }
    }
  }
}
