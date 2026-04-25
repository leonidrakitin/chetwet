import { useCopilotReply } from '../useCopilotReply';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useUISettings } from 'dashboard/composables/useUISettings';
import approvalRequestsApi from 'dashboard/api/captain/approvalRequests';

vi.mock('dashboard/composables/useCaptain');
vi.mock('dashboard/composables/useUISettings');
vi.mock('dashboard/composables', () => ({
  useTrack: vi.fn(),
}));
vi.mock('dashboard/api/captain/approvalRequests', () => ({
  default: {
    generateDraft: vi.fn(),
    resolve: vi.fn(),
  },
}));
vi.mock('dashboard/helper/AnalyticsHelper/events', () => ({
  CAPTAIN_EVENTS: {
    APPROVAL_DRAFT_USED: 'approval_draft_used',
    APPROVAL_DRAFT_APPLIED: 'approval_draft_applied',
    APPROVAL_DRAFT_DISMISSED: 'approval_draft_dismissed',
    GENERATION_FAILED: 'generation_failed',
    FOLLOW_UP_SENT: 'follow_up_sent',
    REWRITE_USED: 'rewrite_used',
    REWRITE_APPLIED: 'rewrite_applied',
    REWRITE_DISMISSED: 'rewrite_dismissed',
    SUMMARIZE_USED: 'summarize_used',
    SUMMARIZE_APPLIED: 'summarize_applied',
    SUMMARIZE_DISMISSED: 'summarize_dismissed',
    REPLY_SUGGESTION_USED: 'reply_suggestion_used',
    REPLY_SUGGESTION_APPLIED: 'reply_suggestion_applied',
    REPLY_SUGGESTION_DISMISSED: 'reply_suggestion_dismissed',
  },
}));

describe('useCopilotReply', () => {
  const followUpMock = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    useCaptain.mockReturnValue({
      processEvent: vi.fn(),
      followUp: followUpMock,
      currentChat: { value: { id: 42 } },
    });
    useUISettings.mockReturnValue({ updateUISettings: vi.fn() });
  });

  describe('submitApprovalAsIs', () => {
    it('resolves the approval request with the operator-typed text without calling the rewrite API', async () => {
      approvalRequestsApi.generateDraft.mockResolvedValue({
        data: { draft: 'Draft from LLM', follow_up_context: { id: 'ctx' } },
      });
      approvalRequestsApi.resolve.mockResolvedValue({});

      const copilot = useCopilotReply();
      await copilot.startApprovalDraft('approval-1', 0);

      const sent = await copilot.submitApprovalAsIs('My operator message');

      expect(approvalRequestsApi.resolve).toHaveBeenCalledWith('approval-1', {
        selectedOptionIndex: 0,
        customResponse: 'My operator message',
      });
      expect(followUpMock).not.toHaveBeenCalled();
      expect(sent).toBe('My operator message');
      expect(copilot.isApprovalDraftMode.value).toBe(false);
    });

    it('is a no-op when the editor is empty', async () => {
      approvalRequestsApi.generateDraft.mockResolvedValue({
        data: { draft: 'Draft', follow_up_context: { id: 'ctx' } },
      });

      const copilot = useCopilotReply();
      await copilot.startApprovalDraft('approval-2', 0);

      const sent = await copilot.submitApprovalAsIs('   ');

      expect(approvalRequestsApi.resolve).not.toHaveBeenCalled();
      expect(sent).toBe('');
    });
  });

  describe('improveApprovalDraft', () => {
    it('runs the LLM follow-up rewrite with the operator-typed text', async () => {
      approvalRequestsApi.generateDraft.mockResolvedValue({
        data: { draft: 'Draft', follow_up_context: { id: 'ctx-1' } },
      });
      followUpMock.mockResolvedValue({
        message: 'Improved draft',
        followUpContext: { id: 'ctx-2' },
      });

      const copilot = useCopilotReply();
      await copilot.startApprovalDraft('approval-3', 0);

      await copilot.improveApprovalDraft('Tighten this please');

      expect(followUpMock).toHaveBeenCalledWith(
        expect.objectContaining({ message: 'Tighten this please' })
      );
      expect(approvalRequestsApi.resolve).not.toHaveBeenCalled();
    });
  });
});
