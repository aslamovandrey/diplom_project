pipeline {

    agent any

    environment {

        REGISTRY = "cr.yandex/crpptbfa7s6gcd28ucld"

        IMAGE_TAG = "${BUILD_NUMBER}"

    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Registry Login') {
            steps {
                sh '''
                docker login \
                --username iam \
                --password $(yc iam create-token) \
                cr.yandex
                '''
             }
        }

        stage('Build user_service') {
            steps {
                sh """
                docker build \
                -t $REGISTRY/user-service:$IMAGE_TAG \
                ./messenger_ajax/user_service
                """
            }
        }

        stage('Push user_service') {
            steps {
                sh """
                docker push \
                $REGISTRY/user-service:$IMAGE_TAG
                """
            }
        }

        stage('Deploy') {
            steps {
                sh """
                helm upgrade --install messenger ./stands/prom/helm/messenger \
                -n messenger-ajax \
                --set userService.image.tag=$IMAGE_TAG
                """
            }
        }

    }

}