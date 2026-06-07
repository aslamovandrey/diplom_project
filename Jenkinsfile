pipeline {
    agent any

    stages {

        stage('Check K8S') {
            steps {
                sh '''
                kubectl get nodes
                '''
            }
        }

        stage('Check Helm') {
            steps {
                sh '''
                helm list -A
                '''
            }
        }
    }
}