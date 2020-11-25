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
            withPRFlowRequest([
                owner: 'aaronwalker',
                repo: 'codebutler',
                branch: 'temp',
                title: 'feat(api): My Cool New Feature',
                body: "# Feature Details:\n\nLook mum I've got markdown\n```yaml\na: b\nc: d\n```",
                labels: ['feature', 'release']
            ]) {
                sh "echo 'test' >> README.md"
            }
        }
      }
    }
  }
}
