# UAT Feedback SF-022 - Opportunity Email Configuration

## Summary

This configuration addresses UAT Feedback SF-022 by implementing the following Salesforce metadata:

1. **Opportunity Record Page** with Activity component configured to show Email tab
2. **Opportunity Page Layout** with Email Quick Action
3. **Manager Profile** with Send Email permissions
4. **Enhanced Email Settings** for Email-to-Salesforce

## Files Created

### 1. Opportunity Record Page (Lightning App Builder)
**File:** `force-app/main/default/flexipages/Opportunity_Record_Page.flexipage-meta.xml`

**Key Configuration:**
- Activity Panel component (`runtime_sales_activities:activityPanel`) included in sidebar
- Email tab explicitly enabled with `emailTabEnabled: true`
- Email tab set as default: `defaultTab: email`
- Also enables Event, Task, and Log Call tabs
- Activity tab is active by default in the sidebar

**Component Properties:**
```xml
<componentInstanceProperties>
    <name>defaultTab</name>
    <value>email</value>
</componentInstanceProperties>
<componentInstanceProperties>
    <name>emailTabEnabled</name>
    <value>true</value>
</componentInstanceProperties>
```

### 2. Opportunity Page Layout
**File:** `force-app/main/default/layouts/Opportunity-Opportunity Layout.layout-meta.xml`

**Key Configuration:**
- Includes standard Quick Actions in the following order:
  1. `FeedItem` (Post)
  2. `NewTask`
  3. `NewEvent`
  4. `LogACall`
  5. **`SendEmail`** ← Email action for sending emails
  6. `NewContact`
  7. `NewCase`

**Quick Actions Configuration:**
```xml
<quickActionList>
    <quickActionListItems>
        <quickActionName>SendEmail</quickActionName>
    </quickActionListItems>
    ...
</quickActionList>
```

### 3. Manager Profile
**File:** `force-app/main/default/profiles/Manager.profile-meta.xml`

**Key Configuration:**
- Full Salesforce license
- **Email Permissions Enabled:**
  - `EmailAdministration: true` - Allows email administration
  - `ListEmailSend: true` - Allows sending list emails
- Standard send email permission (implicitly granted via Activities Access)
- Full CRUD on Opportunity, Account, Contact, Lead objects
- View All Data permission
- Lightning Experience enabled

**Email-Related Permissions:**
```xml
<userPermissions>
    <enabled>true</enabled>
    <name>ActivitiesAccess</name>
</userPermissions>
<userPermissions>
    <enabled>true</enabled>
    <name>EmailAdministration</name>
</userPermissions>
<userPermissions>
    <enabled>true</enabled>
    <name>ListEmailSend</name>
</userPermissions>
```

### 4. Enhanced Email Settings
**File:** `force-app/main/default/settings/EnhancedEmail.settings-meta.xml`

**Key Configuration:**
- Enhanced Email enabled: `enableEnhancedEmails: true`
- Email-to-Salesforce enabled: `enableEmailToSalesforce: true`

## Deployment Instructions

### Deploy to Salesforce Org

```bash
sf project deploy start --source-dir force-app/main/default -o <your-org-alias>
```

Or deploy specific metadata:

```bash
sf project deploy start \
  --metadata "FlexiPage:Opportunity_Record_Page" \
  --metadata "Layout:Opportunity-Opportunity Layout" \
  --metadata "Profile:Manager" \
  --metadata "Settings:EnhancedEmail" \
  -o <your-org-alias>
```

## Verification Steps

### 1. Verify Opportunity Record Page (Lightning App Builder)

1. Navigate to **Setup** → **Lightning App Builder**
2. Search for "Opportunity Record Page"
3. Click **Edit** to open in App Builder
4. Check the **Sidebar** region:
   - Verify `Activity` component is present
   - Click on the Activity component to view properties
   - Confirm these settings:
     - ✅ Email tab enabled
     - ✅ Default tab: Email
     - ✅ Event tab enabled
     - ✅ Task tab enabled
     - ✅ Log Call tab enabled

**Expected Result:** Activity component shows Email as the default tab with email composition enabled.

### 2. Verify Opportunity Page Layout Quick Actions

1. Navigate to **Setup** → **Object Manager** → **Opportunity**
2. Click **Page Layouts** → **Opportunity Layout**
3. Look at the **Salesforce Mobile and Lightning Experience Actions** section
4. Verify the following actions are present in this order:
   - Post (`FeedItem`)
   - New Task (`NewTask`)
   - New Event (`NewEvent`)
   - Log a Call (`LogACall`)
   - **Send Email (`SendEmail`)** ← Critical action
   - New Contact (`NewContact`)
   - New Case (`NewCase`)

**Expected Result:** "Send Email" action appears in the Quick Actions list.

### 3. Verify Manager Profile Permissions

1. Navigate to **Setup** → **Profiles** → **Manager**
2. Check **System Permissions**:
   - ✅ Activities Access (enables Task/Event/Email creation)
   - ✅ Email Administration
   - ✅ List Email Send
3. Check **Object Settings** → **Opportunity**:
   - ✅ Read, Create, Edit, Delete
   - ✅ View All, Modify All
4. Check **Object Settings** → **Task & Event**:
   - ✅ Create permission enabled

**Expected Result:** Manager profile has all email-related permissions enabled.

### 4. Verify Enhanced Email Settings

1. Navigate to **Setup** → **Email Administration** → **Enhanced Email**
2. Verify these settings:
   - ✅ **Enhanced Email** is enabled
   - ✅ **Email-to-Salesforce** is enabled

**Alternative Check - Via Settings:**
1. Navigate to **Setup** → **Quick Find** → "Email-to-Salesforce"
2. Verify Email-to-Salesforce is active

**Expected Result:** Both Enhanced Email and Email-to-Salesforce are enabled.

## Testing the Configuration

### End-to-End Test

1. **Log in as a user with Manager profile**
2. **Navigate to any Opportunity record**
3. **Check Activity Component:**
   - Verify the Activity component appears in the sidebar
   - Verify Email tab is visible and is the default/active tab
4. **Send Email via Quick Action:**
   - Click on the **Actions** menu (top-right or highlights panel)
   - Verify **Send Email** action appears in the list
   - Click **Send Email**
   - Compose test email and send
5. **Verify Email appears in Activity History:**
   - Check that sent email appears in Activity timeline
   - Verify email is logged under Opportunity

**Expected Result:** User can successfully send emails from Opportunity record page, and emails are tracked in Activity history.

## Related Configuration

### Quick Action Definition (Standard - No deployment needed)
The `SendEmail` quick action is a standard Salesforce action available on all standard objects. No custom quick action metadata file is required.

### Activity Panel Features
The `runtime_sales_activities:activityPanel` component provides:
- Email composer with templates
- Event scheduling
- Task creation
- Call logging
- Activity timeline view

## Troubleshooting

### If Email tab doesn't appear:
1. Verify Enhanced Email is enabled (Setup → Enhanced Email)
2. Check user profile has "Activities Access" permission
3. Confirm Activity component is on the Lightning page
4. Check `emailTabEnabled` property is set to `true` in the flexipage

### If Send Email action is missing:
1. Verify it's in the page layout Quick Actions section
2. Check the user's profile has permission to create Tasks/Events
3. Ensure the action wasn't removed from the page layout
4. Verify the user has "Send Email" permission (via Activities Access)

### If emails don't send:
1. Check Enhanced Email is enabled
2. Verify Email-to-Salesforce is configured
3. Check user's email deliverability settings
4. Verify Organization-Wide Email Address is configured (if needed)

## Additional Setup (If Required)

### Email-to-Salesforce Routing
If Email-to-Salesforce routing addresses need to be configured:
1. Setup → Email-to-Salesforce
2. Click "My Email to Salesforce"
3. Note the unique email address
4. Configure email forwarding rules as needed

### Email Templates
To provide email templates for the Activity panel:
1. Setup → Email Templates
2. Create Classic Email Templates
3. Templates will be available in the Email composer

### Email Relay or Deliverability
If additional email authentication is needed:
1. Setup → Deliverability
2. Configure SPF, DKIM, or DMARC as needed
3. Set up Organization-Wide Email Addresses (Setup → Organization-Wide Addresses)

## References

- [Salesforce Enhanced Email Documentation](https://help.salesforce.com/s/articleView?id=sf.emailadmin_enhanced_email_overview.htm)
- [Email-to-Salesforce Setup Guide](https://help.salesforce.com/s/articleView?id=sf.email_to_salesforce_parent.htm)
- [Activity Component for Lightning Pages](https://help.salesforce.com/s/articleView?id=sf.activities_component.htm)
- [Quick Actions in Lightning Experience](https://help.salesforce.com/s/articleView?id=sf.actions_overview.htm)

## Compliance with SF-022 Requirements

✅ **Lightning App Builder - Opportunity Record Page:**
- Activity component included and configured
- Email tab enabled and set as default

✅ **Opportunity Page Layout Quick Actions:**
- "Send Email" action present in Quick Actions list

✅ **Enhanced Email / Email-to-Salesforce:**
- Enhanced Email settings configured and enabled
- Email-to-Salesforce enabled in settings metadata

✅ **Manager Profile:**
- Send Email permission enabled via ActivitiesAccess
- EmailAdministration permission enabled
- ListEmailSend permission enabled
- Full access to Opportunity object

## Notes

- The configuration uses standard Salesforce components and settings
- No custom Apex or Lightning Web Components required
- All configurations follow Salesforce best practices
- Compatible with Salesforce API version 64.0
- Manager profile includes additional permissions for comprehensive functionality
