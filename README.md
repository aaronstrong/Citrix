# Why Citrix Autodeploy

The idea behind this repo is to be able to deploy a fully functional Citrix environment that auto-deploys after answering a few key questions.  After the questions have been answered, the script will use that information and deploy the environment. I was tired of having to reset my lab each time. This is not intended to be used for production.

# Prerequirements

  - Hypervisor: VMware Only
  - An existing Windows template with VMtools install and not domain joined
  - An understanding of PowerShell and PowerCLI if you want to modify
  - A copy of a Citrix ISO
  - An existing Active Directory Domain
  - These scripts :)

# How it Works

Start by running the main.ps1 script.  This is the ..main... script that calls the other scripts. It will connect into the VMware VCSA, use the template you specify and build the VM. Once the VM is built, the script will change the IP address, join it to the domain, and make a firewall exception to allow ICMP.

After the base VM is created and domain joined, it will then copy the ISO file to that VM and begin installing the differnet Citrix components that were specified earlier in the script.

# Testing

As of 11/29/18 my template is a Windows 2016 Server and I've only deployed one full VM with all the Citrix roles installed (Controller, StoreFront, SQL Express, and Director).

I have not tried to install the VDA or other components at the same time, even though I've made the script to be able to do it. Try and let me know.
