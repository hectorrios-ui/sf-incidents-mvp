# Email-to-Case Configuration

This document describes the Email-to-Case setup and configuration for the Salesforce org.

## What's Included

### 1. Email-to-Case Settings (`Case.settings-meta.xml`)
Enables Email-to-Case functionality with the following features:
- **Email-to-Case**: Enabled
- **On-Demand Email-to-Case**: Enabled
- **Thread ID in Body**: Enabled (for email threading)
- **Thread ID in Subject**: Enabled (for email threading)
- **Owner Notification**: Enabled (notifies case owner on new comments)
- **Over Email Limit Action**: Bounce
- **Unauthorized Sender Action**: Bounce
- **Case Feed**: Enabled

### 2. Case Record Page (`Case_Record_Page.flexipage-meta.xml`)
Lightning page layout for Case records with:
- **Highlights Panel**: Configured to show quick actions
- **Activity Tab**: Includes `runtime_sales_activities:activityPanel` for email and activity management
- **Related Lists Tab**: Shows related records
- **Detail Tab**: Shows case details
- **Chatter/Collaborate Tab**: For internal collaboration

### 3. Quick Actions
Two quick actions configured for Case records:
- **Send Email** (`Case.SendEmail.quickAction-meta.xml`): Allows sending emails directly from Case records
- **Log a Call** (`Case.LogACall.quickAction-meta.xml`): Allows logging call activities

### 4. Case Page Layout (`Case-Case Layout.layout-meta.xml`)
Standard layout with:
- Case information fields (Status, Priority, Type, Reason, etc.)
- Quick actions in the highlights panel (Send Email, Log a Call, Post, New Task, New Event)
- Related lists including:
  - Activities (Open/Closed)
  - Case Comments
  - Related Cases
  - **Email Messages** (shows email correspondence)
  - Files

## Deployment

Deploy this metadata to your Salesforce org using:

```bash
sf project deploy start --manifest manifest/package.xml
```

Or deploy specific components:

```bash
sf project deploy start --source-dir force-app/main/default/settings
sf project deploy start --source-dir force-app/main/default/flexipages
sf project deploy start --source-dir force-app/main/default/quickActions
sf project deploy start --source-dir force-app/main/default/layouts
```

## Post-Deployment Configuration

After deploying the metadata, you need to:

### 1. Verify Email-to-Case is Enabled
1. Navigate to **Setup** > **Feature Settings** > **Service** > **Email-to-Case**
2. Verify that Email-to-Case is enabled
3. Configure email routing addresses if needed

### 2. Set Up Email-to-Case Routing
1. In Setup, go to **Email-to-Case** settings
2. Click **Edit** on Routing Addresses or create a new one
3. Configure:
   - Email address (e.g., support@yourcompany.com)
   - Case origin
   - Case priority
   - Task settings
   - Email-to-Case agent (for On-Demand Email-to-Case)

### 3. Assign the Case Page Layout
1. Go to **Setup** > **Object Manager** > **Case** > **Lightning Record Pages**
2. Activate the "Case Record Page" and assign it to relevant app and profiles
   - OR -
1. Go to **Setup** > **Object Manager** > **Case** > **Page Layouts**
2. Assign "Case Layout" to the appropriate profiles

### 4. Verify Email Actions
1. Open any Case record
2. Check that the **Send Email** action appears in the highlights panel
3. Verify the Activity tab shows the activity composer with email option
4. Confirm Email Messages related list is visible

## Testing Email-to-Case

1. Send an email to your configured Email-to-Case address
2. Verify a Case is automatically created
3. Check that the email appears in the Email Messages related list
4. Reply to the customer using the "Send Email" action
5. Verify thread continuity (subsequent emails should be added to the same Case)

## Features Enabled

✅ Email-to-Case enabled in settings
✅ Send Email quick action added to Case layout
✅ Activity panel with email composer in Lightning page
✅ Email Messages related list on Case layout
✅ Case Feed enabled for activity tracking
✅ Thread ID tracking for email conversations
✅ Owner notifications for new case comments

## Troubleshooting

### Email-to-Case Not Working
- Verify the feature is enabled in Setup > Email-to-Case
- Check routing address configuration
- Ensure email service has proper SPF/DKIM setup
- Review Email-to-Case logs in Setup

### Send Email Action Not Appearing
- Verify quick action is deployed
- Check page layout assignment to profile
- Clear browser cache and refresh
- Verify user has permission to send emails

### Email Messages Not Appearing
- Check Email Messages related list is added to layout
- Verify EmailMessage object permissions
- Ensure email delivery settings are correct

## Additional Resources

- [Salesforce Email-to-Case Documentation](https://help.salesforce.com/articleView?id=sf.customizesupport_email.htm)
- [Quick Actions Documentation](https://help.salesforce.com/articleView?id=sf.actions_overview.htm)
- [Lightning Page Configuration](https://help.salesforce.com/articleView?id=sf.lightning_app_builder_overview.htm)
