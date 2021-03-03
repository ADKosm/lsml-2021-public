#!/usr/bin/env bash

set -e

echo "Updating..."
sudo apt-get update -y
sudo apt-get install python3-pip openjdk-8-jdk-headless -y

echo "Install python deps..."
sudo pip3 install jupyter findspark psutil


echo "Install spark"
sudo wget https://apache-mirror.rbc.ru/pub/apache/spark/spark-3.1.1/spark-3.1.1-bin-hadoop2.7.tgz
sudo mkdir -p /spark
sudo tar xf spark-3.1.1-bin-hadoop2.7.tgz -C /spark

echo "Run jupyter..."
sudo mkdir -p /jupyter
sudo chmod 0777 -R /jupyter
cd /jupyter
sudo tmux new -s spark -d "jupyter notebook --no-browser --ip=0.0.0.0 --allow-root --NotebookApp.token=" 2> /dev/null

echo "DONE!"
