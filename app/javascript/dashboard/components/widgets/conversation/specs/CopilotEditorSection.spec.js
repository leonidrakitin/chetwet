import { mount } from '@vue/test-utils';
import CopilotEditorSection from '../CopilotEditorSection.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key =>
      ({
        'CONVERSATION.APPROVAL_DRAFT.IMPROVE': 'Improve',
        'CONVERSATION.APPROVAL_DRAFT.SEND_AS_IS': 'Send as-is',
      })[key] || key,
  }),
}));

const editorStubProps = {
  modelValue: { type: String, default: '' },
  generatedContent: { type: String, default: '' },
};

const stubs = {
  CopilotEditor: {
    name: 'CopilotEditor',
    props: editorStubProps,
    emits: ['update:modelValue', 'send'],
    template:
      '<div data-testid="copilot-editor-stub"><button data-testid="stub-send" @click="$emit(\'send\')">send</button></div>',
  },
  CaptainLoader: { template: '<span />' },
  NextButton: {
    name: 'NextButton',
    props: ['disabled', 'label'],
    emits: ['click'],
    template:
      '<button :disabled="disabled" :data-testid="$attrs[\'data-testid\']" @click="$emit(\'click\')">{{ label }}</button>',
  },
};

const factory = (props = {}) =>
  mount(CopilotEditorSection, {
    props: {
      showCopilotEditor: true,
      isGeneratingContent: false,
      generatedContent: 'Draft body',
      isPopout: false,
      isApprovalMode: true,
      ...props,
    },
    global: { stubs },
  });

describe('CopilotEditorSection — approval mode', () => {
  it('renders Improve and Send-as-is buttons', () => {
    const wrapper = factory();
    expect(wrapper.find('[data-testid="approval-improve"]').exists()).toBe(
      true
    );
    expect(wrapper.find('[data-testid="approval-send-as-is"]').exists()).toBe(
      true
    );
  });

  it('disables both action buttons when the editor is empty', () => {
    const wrapper = factory();

    const improve = wrapper.find('[data-testid="approval-improve"]');
    const sendAsIs = wrapper.find('[data-testid="approval-send-as-is"]');

    expect(improve.attributes('disabled')).toBeDefined();
    expect(sendAsIs.attributes('disabled')).toBeDefined();
  });

  it('does NOT clear input or emit "send" when Enter triggers the editor in approval mode', async () => {
    const wrapper = factory();

    // simulate operator typing
    wrapper.vm.copilotEditorContent = 'My custom variant';
    await wrapper.vm.$nextTick();

    // Enter inside CopilotEditor stub triggers @send → onSend
    await wrapper.find('[data-testid="stub-send"]').trigger('click');

    expect(wrapper.emitted('send')).toBeUndefined();
    // input must persist — caller must explicitly choose Improve or Send-as-is
    expect(wrapper.vm.copilotEditorContent).toBe('My custom variant');
  });

  it('emits submitAsIs with the typed text when Send-as-is is clicked', async () => {
    const wrapper = factory();

    wrapper.vm.copilotEditorContent = 'send this verbatim';
    await wrapper.vm.$nextTick();

    await wrapper.find('[data-testid="approval-send-as-is"]').trigger('click');

    expect(wrapper.emitted('submitAsIs')).toBeTruthy();
    expect(wrapper.emitted('submitAsIs')[0]).toEqual(['send this verbatim']);
  });

  it('emits improve with the typed text when Improve is clicked', async () => {
    const wrapper = factory();

    wrapper.vm.copilotEditorContent = 'rewrite this';
    await wrapper.vm.$nextTick();

    await wrapper.find('[data-testid="approval-improve"]').trigger('click');

    expect(wrapper.emitted('improve')).toBeTruthy();
    expect(wrapper.emitted('improve')[0]).toEqual(['rewrite this']);
  });
});

describe('CopilotEditorSection — non-approval mode', () => {
  it('keeps the existing send-and-clear behaviour for follow-up rewrites', async () => {
    const wrapper = factory({ isApprovalMode: false });

    wrapper.vm.copilotEditorContent = 'follow up question';
    await wrapper.vm.$nextTick();

    await wrapper.find('[data-testid="stub-send"]').trigger('click');

    expect(wrapper.emitted('send')).toBeTruthy();
    expect(wrapper.emitted('send')[0]).toEqual(['follow up question']);
    expect(wrapper.vm.copilotEditorContent).toBe('');
    expect(wrapper.find('[data-testid="approval-improve"]').exists()).toBe(
      false
    );
  });
});
