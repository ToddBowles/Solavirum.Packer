# What is this?
This repository contains Packer templates and Powershell scripts that create Amazon AMI's for reuse when working with AWS EC2.

The main purposes for creating these AMI's is to decrease the time it takes to spin up an environment (i.e. reducing the software and configuration we do on a per environment basis) and to ensure we have some consistency with the underlying machines in our environments.

[Packer](https://www.packer.io/) is a tool that allows for the automated creation of machines, which in our case means Amazon Machine Images (AMI's). It can also be used to create other virtual machines, like VMWare.

Powershell is a creation of the devil, but a necessary evil for ease of use.

# How do I use it?
Initially extracted from an environment that leverages TeamCity heavily, there is a script in the root called `CreateImageWithPacker.ps1` containing all of the logic that was in TeamCity.

## But I need to change things!
The repository is structured such that the `/src` directory contains a directory for each unique AMI template that we maintain.

Find the ami you need to edit (or make a new one) and follow the pattern from the others.

The main point of usage is the `make.ps1` script file inside each AMI definition directory. Its backed up by a Make function inside `/scripts/packer/Functions-Packer.ps`, which commonalises a lot of logic.

The make scripts all require AWS credentials.

## Trickses
AMIs are created in two different AWS accounts, which means different networking settings (like VPC, Subnet, Security Group, etc). These differences are encapsulated in a config system that allows you to use common defaults for both dev and prod, and then also allows you to override those defaults inside specific configuration directories. See `Functions-Packer.Make` for implementation details, and `/src/common/conf` for the common defaults. Overrides are expected to be in `/src/{ami-directory}/conf` named the same way as the defaults.

Parameters in local directories override those in the common defaults (if present).

## Tests
There is usually a Pester test for each AMI (`make.Tests.ps1`) sitting in parallel to the make script. These are NOT automatically run during a build/checkin (because this repository does not create a versioned package), but are useful during development.

Credentials for these tests (i.e. AWS stuff mostly) are handled via the normal Pester credentials arrangement (that is, if you supply them directly it will use them, but it will also source them from a file inside C:\credentials as a development aid). Using VSCode you can also run the tests directly by selecting the correct launch config and hitting F5 (run) while the test file has focus.

Be warned, the tests clean up the AMI if it was created, but they might leave stuff behind as well (for example, the Octopus linux instance will test some Octopus registration stuff, which means it might leave behind machines)

# Who is responsible?
This repository was migrated from the Gateway team inside Console. Contributors include Jonathan Easy and Brad Bow.