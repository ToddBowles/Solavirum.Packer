ErrorTrap() { 
    echo "An error occurred while running the test script"
    exit 1 
}
trap ErrorTrap ERR

echo "Executing a test script to validate AMI functionality"

sudo python "/opt/octopus/octopus_register_target.py" \
    --octopusurl "$octopus_url" \
    --octopusapikey "$octopus_key" \
    --octopusenvironmentname "scratch-1" \
    --octopusroles "test-role" \
    --octopusaccount "sshkeypair-console" \
    --logfile "/var/log/octopus-registration.log" \
    --sshkeyfilepath "/etc/ssh/ssh_host_rsa_key.pub"

sudo python "/opt/octopus/octopus_unregister_target.py" \
    --octopusurl "$octopus_url" \
    --octopusapikey "$octopus_key" \
    --logfile "/var/log/octopus-registration.log"