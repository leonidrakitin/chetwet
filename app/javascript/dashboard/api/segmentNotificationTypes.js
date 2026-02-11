import ApiClient from './ApiClient';

class SegmentNotificationTypesAPI extends ApiClient {
  constructor() {
    super('segment_notification_types', { accountScoped: true });
  }
}

export default new SegmentNotificationTypesAPI();
