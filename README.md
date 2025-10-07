# Azure Web App with Entra ID Authentication

This Terraform configuration deploys an Azure Web App with Azure Entra ID (formerly Azure AD) authentication using SSO. The solution includes:

- Azure Web App with Linux App Service Plan
- Azure Entra ID Application Registration
- Service Principal with client secret
- Entra ID Security Group for user authorization
- Application Insights for monitoring
- Staging deployment slot

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Entra ID      │    │   Azure Web App  │    │  Application    │
│   User/Group    │───▶│   with Auth      │───▶│   Insights      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│ App Registration│    │  Service Plan    │
│ + Service       │    │  (Linux)         │
│ Principal       │    └──────────────────┘
└─────────────────┘
```

## Features

- **SSO Authentication**: Users authenticate using their existing Entra ID credentials
- **Group-based Authorization**: Only members of a specific Entra ID group can access the application
- **Secure Token Management**: Client secret managed through Terraform with 2-year expiration
- **Monitoring**: Application Insights integration for performance monitoring
- **Staging Environment**: Separate staging slot for testing
- **HTTPS Only**: Enforced secure connections
- **Managed Identity**: System-assigned managed identity for secure Azure service access

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** installed (version >= 1.9.7)
3. **Appropriate Azure Permissions**:
   - Contributor role on the subscription
   - Application Administrator role in Entra ID
   - Ability to create security groups

## Configuration

### Required Variables

Update the variables in `variables.tf` or create a `terraform.tfvars` file:

```hcl
resource_group_name    = "rg-webapp-entraid-demo"
location              = "East US"
web_app_name          = "webapp-entraid-demo"
app_registration_name = "webapp-entraid-demo-app"
entra_group_name      = "webapp-users-group"
environment           = "dev"
```

### Custom Domain (Optional)

To use a custom domain, uncomment and configure the custom hostname binding in `main.tf`:

```hcl
resource "azurerm_app_service_custom_hostname_binding" "main" {
  hostname            = "your-domain.com"
  app_service_name    = azurerm_linux_web_app.main.name
  resource_group_name = azurerm_resource_group.main.name
}
```

## Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Validate Configuration**:
   ```bash
   terraform validate
   ```

3. **Plan Deployment**:
   ```bash
   terraform plan
   ```

4. **Apply Configuration**:
   ```bash
   terraform apply -auto-approve
   ```

## Post-Deployment Configuration

### 1. Add Users to the Entra ID Group

After deployment, add users to the authorized group:

1. Navigate to the Azure Portal
2. Go to Azure Active Directory > Groups
3. Find the group created by Terraform (check outputs for the exact name)
4. Add users who should have access to the web application

### 2. Configure Application Code

Your web application code should handle authentication tokens. Here's an example for Node.js:

```javascript
app.get('/profile', (req, res) => {
  // Access user information from headers
  const userPrincipal = req.headers['x-ms-client-principal'];
  const userInfo = JSON.parse(Buffer.from(userPrincipal, 'base64').toString());
  
  // Check group membership
  const userGroups = userInfo.claims.find(c => c.typ === 'groups');
  
  res.json({
    user: userInfo,
    groups: userGroups
  });
});
```

### 3. API Permissions (if needed)

If your application needs additional Microsoft Graph permissions:

1. Go to Azure Portal > App registrations
2. Select your application
3. Go to API permissions
4. Add required permissions
5. Grant admin consent

## Security Considerations

- **Client Secret Rotation**: The client secret expires in 2 years. Set up monitoring and rotation procedures.
- **Group Membership**: Regularly review group membership to ensure appropriate access.
- **Application Logs**: Monitor application logs through Application Insights.
- **HTTPS Only**: The configuration enforces HTTPS-only connections.

## Monitoring and Troubleshooting

### Application Insights

Monitor your application through Application Insights:
- Performance metrics
- Request failures
- Custom telemetry
- User sessions

### Authentication Logs

Check authentication logs in:
- Azure Portal > App Service > Authentication
- Azure Portal > Entra ID > Sign-in logs

### Common Issues

1. **Users can't access the application**:
   - Verify user is member of the authorized group
   - Check group assignment in the app configuration
   - Review sign-in logs in Entra ID

2. **Authentication not working**:
   - Verify redirect URIs in app registration
   - Check client secret hasn't expired
   - Confirm tenant ID and client ID are correct

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Outputs

After successful deployment, you'll receive:
- Web App URL
- Application Registration details
- Entra ID Group information
- Direct Azure Portal links
- Application Insights details

## Cost Optimization

- **App Service Plan**: Using B1 tier by default (adjust in variables.tf)
- **Application Insights**: Pay-per-use model
- **Consider Reserved Instances**: For production workloads

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Azure documentation
3. Open an issue in this repository
