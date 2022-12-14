#!/bin/bash

names=("nginx-a" "nginx-b" "nginx-c")
namespaces=("department-a" "department-b")
actions=("Rebooted" "Scheduled" "Pulling" "Pulled" "Created")
reasons=("NodeReady" "NodeNotReady")
types=("Normal" "Warning")
messages=("Debug Me" "Hello World")

names_size=${#names[@]}
namespaces_size=${#namespaces[@]}
actions_size=${#actions[@]}
reasons_size=${#reasons[@]}
types_size=${#types[@]}
messages_size=${#messages[@]}

for value in {1..10000}; do
  k8s-event-generator --kind Pod \
    --name ${names[$(($RANDOM % $names_size))]} \
    --namespace ${namespaces[$(($RANDOM % $namespaces_size))]} \
    --action ${actions[$(($RANDOM % actions_size))]} \
    --reason ${reasons[$(($RANDOM % reasons_size))]} \
    --type ${types[$(($RANDOM % types_size))]} \
    --message ${messages[$(($RANDOM % messages_size))]}
  sleep 0.1
done
