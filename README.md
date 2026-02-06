<p align="center" style="margin-bottom: 0px;">
  <img src="https://github.com/oreolag/cli/blob/main/cli-removebg.png" 
       align="center" style="width: 200px; height: auto;">
</p>

<h1 align="center">
  odev
</h1> 

**Hyperion Management** is a unified automation solution built on the RedHat Ansible Automation Platform. It simplifies infrastructure configuration, including OS optimization and networking, user management, and orchestration of essential workflows. These workflows cover tasks such as installing Hyperion Development and Composer, as well as specific client workflows created through Pharos.

## Sections
* [Usage](#usage)
* [License](#license)

# Usage
## HACC Development 
### Local
* ```./ansible-play.sh ethz-hacc/hdev-local-install.yml alveo-box-01.inf.ethz.ch,alveo-u55c-01.inf.ethz.ch```
* ```./ansible-play.sh ethz-hacc/hdev-local-install.yml alveo-box-01.inf.ethz.ch,alveo-u55c-01.inf.ethz.ch get,help```

### Repo
* ```./ansible-play.sh ethz-hacc/hdev-repo-install.yml hacc-box-01.inf.ethz.ch```

## HACC Composer 
### Install
* ```./ansible-play.sh ethz-hacc/hcmp-local-install.yml hacc-box-02.inf.ethz.ch```

### Uninstall
* ```./ansible-play.sh ethz-hacc/hcmp-local-uninstall.yml hacc-box-01.inf.ethz.ch,hacc-box-02.inf.ethz.ch```

## Other playbooks
* ```./ansible-play.sh ethz-hacc/welcome-msg-deploy.yml``` 
* ```./ansible-play.sh ethz-hacc/welcome-msg-deploy.yml alveo-box-01.inf.ethz.ch```
* ```./ansible-play.sh ethz-hacc/welcome-msg-deploy.yml hacc_boxes```
* ```./ansible-play.sh ethz-hacc/welcome-msg-deploy.yml alveo-box-01.inf.ethz.ch,alveo-u55c-01.inf.ethz.ch```

# License
Copyright (C) 2025 Oreol KLG
All rights reserved.

This software is proprietary and confidential. Unauthorized distribution, copying, or modification is prohibited. Access is granted only to authorized users under the terms of a valid subscription agreement.