#!/bin/bash

# Install the Az.ManagementPartner module
az extension add --name managementpartner

# Set the management partner
az managementpartner create --partner-id 1465247

# Show the management partner and write output
az managementpartner show --query "{PartnerId:partnerId, PartnerTenantId:partnerTenantId}" -o table