pipeline {
  agent any
  triggers {
    // webhook on tag create
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Setup') { steps { sh 'npm ci' } }
    stage('Build') {
      steps {
        sh 'npm run build | tee build.log'
      }
    }
    stage('Run Docker') {
      steps {
        script {
          def tag = env.GIT_TAG ?: env.GIT_COMMIT
          sh "docker build -t react:${tag} ."
          sh "docker run -d -p 8080:80 --name react_tag_${tag} react:${tag}"
        }
      }
    }
    stage('Smoke Test') {
      steps {
        sh './smoke-test.sh > smoke.log || (cat smoke.log; exit 1)'
      }
    }
    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: 'dist/**,build.log,smoke.log', allowEmptyArchive: false
      }
    }
    stage('Cleanup') {
      steps {
        sh 'docker ps -a --filter "name=react_tag_*" --format "{{.ID}}" | xargs -r docker rm -f'
      }
    }
  }
  post {
    success {
      echo "Build for tag ${env.GIT_TAG} succeeded"
    }
  }
}
