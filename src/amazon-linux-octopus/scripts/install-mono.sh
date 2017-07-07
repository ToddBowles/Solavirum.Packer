libpng15_package="libpng15-1.5.28-3.fc27.x86_64.rpm"

sudo mkdir -p /tmp/mono_dependencies
sudo wget http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/l/$libpng15_package -O /tmp/mono_dependencies/$libpng15_package || exit 1
sudo yum install -y /tmp/mono_dependencies/$libpng15_package
sudo yum install yum-utils
sudo rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
sudo yum-config-manager --add-repo http://download.mono-project.com/repo/centos7/
sudo yum install -y mono-complete-$mono_version
sudo rpm --query mono-complete-$mono_version