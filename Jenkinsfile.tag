pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Setup') {
            steps {
                bat 'npm ci'
            }
        }
        stage('Build') {
            steps {
                bat 'npm run build'
            }
        }
        stage('Run Docker') {
            steps {
                bat 'docker rm -f react-tag || exit /b 0'
                bat 'docker build -t react-tag:%GIT_COMMIT% .'
                bat 'docker run -d -p 8081:80 --name react-tag react-tag:%GIT_COMMIT%'
            }
        }
        stage('Smoke Test') {
            steps {
                bat 'call smoke\\smoke-test.bat'
            }
        }
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'dist/**, smoke/smoke.log', allowEmptyArchive: true
            }
        }
        stage('Cleanup') {
            steps {
                bat 'docker rm -f react-tag || exit /b 0'
            }
        }
    }
}
