def SERVICES = [
    [
        name: "user_service",
        path: "messenger_ajax/user_service",
        image: "user-service",
        helmKey: "userService"
    ],
    [
        name: "message_service",
        path: "messenger_ajax/message_service",
        image: "message-service",
        helmKey: "messageService"
    ],
    [
        name: "web_client",
        path: "messenger_ajax/web_client",
        image: "web-client",
        helmKey: "webClient"
    ]
]

def changedServices = []

pipeline {

    agent any

    environment {
        REGISTRY = "cr.yandex/crpptbfa7s6gcd28ucld"
        NAMESPACE = "messenger-ajax"
        RELEASE = "messenger"
    }

    stages {

        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        stage("Detect changes") {
            steps {
                script {

                    def changedFiles = sh(
                        script: "git diff --name-only HEAD~1 HEAD",
                        returnStdout: true
                    ).trim()

                    println changedFiles

                    SERVICES.each { service ->

                        if (changedFiles.contains(service.path + "/")) {
                            changedServices.add(service)
                        }

                    }

                    if (changedServices.isEmpty()) {
                        currentBuild.result = "SUCCESS"
                        error("No services changed")
                    }

                    println "Changed services:"
                    changedServices.each {
                        println it.name
                    }

                }
            }
        }

        stage("Registry Login") {
            steps {
                sh """
                docker login \
                --username iam \
                --password \$(yc iam create-token) \
                cr.yandex
                """
            }
        }

        stage("Build and Push") {
            steps {
                script {

                    changedServices.each { service ->

                        sh """
                        docker build \
                          -t ${REGISTRY}/${service.image}:${BUILD_NUMBER} \
                          ./${service.path}

                        docker push \
                          ${REGISTRY}/${service.image}:${BUILD_NUMBER}
                        """

                    }

                }
            }
        }

        stage("Deploy") {
            steps {
                script {

                    def helmArgs = ""

                    changedServices.each { service ->

                        helmArgs +=
                        " --set ${service.helmKey}.image.tag=${BUILD_NUMBER}"

                    }

                    sh """
                    helm upgrade --install \
                        ${RELEASE} \
                        stands/prom/helm/messenger\
                        -n ${NAMESPACE} \
                        ${helmArgs}
                    """
                }
            }
        }

        stage("Wait Rollout") {
            steps {
                script {

                    changedServices.each { service ->

                        def deployName =
                            service.image

                        sh """
                        kubectl rollout status \
                          deployment/${deployName} \
                          -n ${NAMESPACE} \
                          --timeout=30s
                        """

                    }

                }
            }
        }

        stage("Smoke Test") {
            steps {
                sh """
                curl -f -H "Host: ajax.local" http://81.26.177.18/login
                curl -f -H "Host: ajax.local" http://81.26.177.18/api/users
                curl -f -H "Host: ajax.local" http://81.26.177.18/api/messages
                """
            }
        }
    }

    post {

        success {
            echo "Deploy successful"
        }

        failure {
            echo "Deploy failed"
        }

    }

}