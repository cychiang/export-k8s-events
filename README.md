# export-k8s-events

A proof of concept system to export and analysis Kubernetes events. The system is able to:
- Longer retention period for generated Kubernetes events
- Ability to analyze events

## Requirements:

- terraform: 1.3.6
- kind: v0.17.0
- kustomize: v4.5.7
- envsubst: 0.21.1
- AWS services:
  - AWS Firehose
  - AWS S3
  - AWS Athena
- AWS credentials and put it into environment variables as following:
  ```bash
  export TF_VAR_access_key=${AWS_ACCESS_KEY}
  export TF_VAR_secret_key=${AWS_SECRET_KEY}
  export TF_VAR_region=${AWS_REGION}
  ```

## System Overview

![image](img/system-design.jpg)

The system contains three parts:

- **Kubernetes**: Collecting events and export to ETL Pipeline
  - We deploy `kubernetes-event-exportter` to export events to `AWS Firehose` 
- **ETL Pipeline**: Process events and store in a reliable centralized storage
  - We configure `AWS Firehose` to transform and store events to `AWS S3` for long term storage
- **Insights**: Ability to run queries to analyze events
  - Create a data table with `AWS Athena` to be able to run queries on those events in s3 bucket

## How to use

The following steps are tested in the MacOS only.

1. Install necessary packages
    ```bash
    # Install terraform
    brew install terraform
    # Install kustomize 
    brew install kustomize
    # Install kind 
    brew install kind
    # Create a Kubernetes cluster with kind
    kind create cluster
    # Install envsubst
    go install github.com/a8m/envsubst/cmd/envsubst@latest
    # Install k8s-event-generator, need to build it from source and move it to /usr/local/bin
    git clone git@github.com:uzxmx/k8s-event-generator.git
    cd k8s-event-generator
    make build 
    cp bin/k8s-event-generator /usr/local/bin
    ```

2. Create AWS infrastructure with terraform
    ```bash
    cd infrastructure
    terraform init
    terraform apply
    export TF_VAR_firehose_s3_stream_name=$(terraform output -raw firehose_s3_stream_name)
    ```

3. Deploy Kubernetes services for testing
    ```bash
    cd services
    kustomize build . | envsubst > services.yaml
    kubectl apply -f services.yaml
    ```

4. Run test script
    ```bash
    cd test
    kustomize build . > test.yaml
    kubectl apply -f test.yaml
    ./generate_events.sh
    ```

5. Create an Athena table in AWS console
    ```sql
    CREATE EXTERNAL TABLE kubernetes_events (
        createdAt string,
        kind string,
        message string,
        name string,
        reason string,
        type string
    )
    PARTITIONED BY (
        namespace string,
        dt string
    )
    ROW FORMAT serde 'org.apache.hive.hcatalog.data.JsonSerDe'
    LOCATION 's3://kubernetes-events-bucket/data/'
    ```
   5.1 Load the partitions with the following query
    ```sql
    MSCK REPAIR TABLE kubernetes_events;
    ```

6. Cleanup 
    ```bash
    cd test/
    kubectl delete -f test.yaml
    cd services/
    kubectl delete -f services.yaml
    cd infrastructure/
    terraform destroy
    ```
   6.1 Drop Athena table
    ```sql
    DROP TABLE `kubernetes_events`;
    ```
