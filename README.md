# What is this?
This repository contains templates and logic for creating a variety of AMIs using Packer, including Amazon Linux w. Octopus Tentacle Registration, Windows Server w. Octopus and ISS and Amazon Linux w. Elasticsearch, Kibana, Logstash, etc (for an ELK stack).

# How do I use it?
The `src` folder contains the majority of the love, with each AMI having its own subdirectory. Each directory contains a make.ps1 script that takes some relatively obvious arguments and will create an AMI out the other end. Each directory also usually contains a Pester test to validating that the AMI can be created successfully, but its heavily dependent on Packer failing in a sane way, so [make sure your scripts report failures correctly](http://www.codeandcompost.com/post/pack-of-lies).