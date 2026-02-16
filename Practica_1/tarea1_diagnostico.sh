#! /bin/bash

echo "Nombre del equipo:"
hostnamectl

echo "Ip del equipo:"
sudo apt install net-tools
ifconfig

echo "Volumen del equipo:"
df -h