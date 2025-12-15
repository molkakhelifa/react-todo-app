pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
    }

    parameters {
        string(name: 'TAG_NAME', defaultValue: 'v1.0.0', description: 'Docker image tag')
        string(name: 'APP_PORT', defaultValue: '8083', description: 'Port exposé (doit être libre)')
    }

    environment {
        IMAGE_NAME = "react:${params.TAG_NAME}"
        CONTAINER_NAME = "react_${params.TAG_NAME.replace('.', '_')}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                bat 'npm ci --prefer-offline'
            }
        }

        stage('Build Application') {
            steps {
                bat 'npm run build'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat "docker build -t ${IMAGE_NAME} ."
            }
        }

        stage('Run Docker Container') {
            steps {
                bat """
                @echo off
                echo Cleaning old container if exists...
                docker rm -f ${CONTAINER_NAME} 2>nul

                echo Running container on port ${params.APP_PORT}...
                docker run -d ^
                  -p ${params.APP_PORT}:80 ^
                  --name ${CONTAINER_NAME} ^
                  ${IMAGE_NAME}
                """
            }
        }

        stage('Smoke Test') {
            steps {
                bat "call smoke\\smoke-test.bat ${params.APP_PORT}"
                archiveArtifacts artifacts: 'smoke.log', allowEmptyArchive: false
            }
        }

        stage('Cleanup') {
            steps {
                bat """
                @echo off
                docker stop ${CONTAINER_NAME} 2>nul
                docker rm ${CONTAINER_NAME} 2>nul
                """
            }
        }
    }

    post {
        success {
            echo "✔ BUILD SUCCESS for ${params.TAG_NAME}"
            echo "✔ App available on http://localhost:${params.APP_PORT}"
        }
        failure {
            echo "✖ BUILD FAILED for ${params.TAG_NAME}"
        }
    }
}
