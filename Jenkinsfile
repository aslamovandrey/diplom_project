pipeline {
    agent any

    stages {

        stage('Check K8S') {

            steps {

                withCredentials([
                    file(
                        credentialsId: 'kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {

                    sh '''
                    echo "KUBECONFIG=$KUBECONFIG"

                    kubectl get nodes
                    '''
                }
            }
        }
    }
}