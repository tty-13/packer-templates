# OPNsense VM

This builds an OPNsense VM on Promox, which was not an easy task, as OPNsense and FreeBSD beneath it have many quirks that made automation a pain to implement.
For now this is more of a proof of concept than anything, since this is not the kind of VM you'd really need as a template. Still I'd like to improve on it and make something similar to cloud-init to quickly deploy an OPNsense VM with custom yet somewhat portable config.

Dependencies :
On OSX you might have trouble with the build script due to BSD sed. This may work by using GNU sed instead.
On gentoo, pwgen and apache-tools are needed for the temporary password generation. (Might be something like apache-utils on your distro)