import advancedFilters from './advancedFilters.json';
import agentBots from './agentBots.json';
import agentMgmt from './agentMgmt.json';
import attributesMgmt from './attributesMgmt.json';
import auditLogs from './auditLogs.json';
import automation from './automation.json';
import bulkActions from './bulkActions.json';
import campaign from './campaign.json';
import campaigns from './campaigns.json';
import cannedMgmt from './cannedMgmt.json';
import chatlist from './chatlist.json';
import components from './components.json';
import contact from './contact.json';
import contactFilters from './contactFilters.json';
import contentTemplates from './contentTemplates.json';
import conversation from './conversation.json';
import csatMgmt from './csatMgmt.json';
import customRole from './customRole.json';
import datePicker from './datePicker.json';
import emoji from './emoji.json';
import general from './general.json';
import generalSettings from './generalSettings.json';
import helpCenter from './helpCenter.json';
import inbox from './inbox.json';
import inboxMgmt from './inboxMgmt.json';
import integrationApps from './integrationApps.json';
import integrations from './integrations.json';
import labelsMgmt from './labelsMgmt.json';
import landing from './landing.json';
import login from './login.json';
import macros from './macros.json';
import mfa from './mfa.json';
import notificationTemplates from './notificationTemplates.json';
import report from './report.json';
import resetPassword from './resetPassword.json';
import search from './search.json';
import setNewPassword from './setNewPassword.json';
import settings from './settings.json';
import signup from './signup.json';
import sla from './sla.json';
import snooze from './snooze.json';
import teamsSettings from './teamsSettings.json';
import whatsappTemplates from './whatsappTemplates.json';
import yearInReview from './yearInReview.json';
import suggestions from './suggestions.json';
import servicesMgmt from './servicesMgmt.json';

export default {
  ...advancedFilters,
  ...agentBots,
  ...agentMgmt,
  ...attributesMgmt,
  ...auditLogs,
  ...automation,
  ...bulkActions,
  ...campaign,
  ...campaigns,
  ...cannedMgmt,
  ...chatlist,
  ...components,
  ...contact,
  ...contactFilters,
  ...contentTemplates,
  ...conversation,
  ...csatMgmt,
  ...customRole,
  ...datePicker,
  ...emoji,
  ...general,
  ...generalSettings,
  ...helpCenter,
  ...inbox,
  ...inboxMgmt,
  ...integrationApps,
  ...integrations,
  ...labelsMgmt,
  ...landing,
  ...login,
  ...macros,
  ...mfa,
  ...notificationTemplates,
  ...report,
  ...resetPassword,
  ...search,
  ...setNewPassword,
  ...settings,
  ...signup,
  ...sla,
  ...snooze,
  ...teamsSettings,
  ...whatsappTemplates,
  ...yearInReview,
  ...suggestions,
  ...servicesMgmt,
  CAPTAIN: {
    ...(integrations.CAPTAIN || {}),
    ...(signup.CAPTAIN || {}),
    ASSISTANTS: {
      ...((integrations.CAPTAIN && integrations.CAPTAIN.ASSISTANTS) || {}),
      ...((signup.CAPTAIN && signup.CAPTAIN.ASSISTANTS) || {}),
      TEMPLATES: {
        ...((integrations.CAPTAIN &&
          integrations.CAPTAIN.ASSISTANTS &&
          integrations.CAPTAIN.ASSISTANTS.TEMPLATES) ||
          {}),
        ...((signup.CAPTAIN &&
          signup.CAPTAIN.ASSISTANTS &&
          signup.CAPTAIN.ASSISTANTS.TEMPLATES) ||
          {}),
        BUTTONS: {
          ...((integrations.CAPTAIN &&
            integrations.CAPTAIN.ASSISTANTS &&
            integrations.CAPTAIN.ASSISTANTS.TEMPLATES &&
            integrations.CAPTAIN.ASSISTANTS.TEMPLATES.BUTTONS) ||
            {}),
          ...((signup.CAPTAIN &&
            signup.CAPTAIN.ASSISTANTS &&
            signup.CAPTAIN.ASSISTANTS.TEMPLATES &&
            signup.CAPTAIN.ASSISTANTS.TEMPLATES.BUTTONS) ||
            {}),
        },
      },
    },
  },
};
