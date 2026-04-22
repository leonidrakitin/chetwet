require 'yaml'

namespace :captain do
  desc 'Run Captain against the anti-hallucination golden dataset. Usage: rake captain:eval[assistant_id,dataset_path]'
  task :eval, %i[assistant_id dataset_path] => :environment do |_, args|
    runner = CaptainEvalRunner.new(
      assistant_id: args[:assistant_id],
      dataset_path: args[:dataset_path]
    )
    runner.run
  end
end

# rubocop:disable Metrics/ClassLength
class CaptainEvalRunner
  DEFAULT_DATASET = Rails.root.join('spec/enterprise/fixtures/captain/golden_dataset.yml').freeze
  REPORT_PATH = Rails.root.join('tmp/captain_eval_report.md').freeze

  def initialize(assistant_id:, dataset_path: nil)
    @assistant_id = assistant_id
    @dataset_path = dataset_path.presence || DEFAULT_DATASET
  end

  def run
    assistant = resolve_assistant!
    cases = load_cases!
    results = cases.map { |kase| evaluate_case(assistant, kase) }
    write_report(assistant, results)
    print_summary(results)
    exit(results.any? { |r| !r[:passed] } ? 1 : 0)
  end

  private

  def resolve_assistant!
    unless @assistant_id
      puts '❌ Provide an assistant id: rake captain:eval[assistant_id]'
      exit 1
    end
    assistant = Captain::Assistant.find_by(id: @assistant_id)
    unless assistant
      puts "❌ Assistant #{@assistant_id} not found"
      exit 1
    end
    assistant
  end

  def load_cases!
    raw = YAML.safe_load_file(@dataset_path, permitted_classes: [Symbol])
    Array(raw['cases'])
  rescue Errno::ENOENT
    puts "❌ Dataset not found at #{@dataset_path}"
    exit 1
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def evaluate_case(assistant, kase)
    started = Time.current
    message_history = build_message_history(kase)
    probe = RunProbe.new
    response = call_runner(assistant, message_history, probe)
    checks = verify(kase, response, probe)
    {
      id: kase['id'],
      intent: kase['intent'],
      input: kase['input'],
      response: response,
      tools_called: probe.tool_names,
      faq_confidence: probe.faq_result&.dig(:confidence) || probe.faq_result&.dig('confidence'),
      actual_policy: infer_policy(response, probe),
      expected_policy: kase['expected_policy'],
      checks: checks,
      passed: checks.all? { |c| c[:passed] },
      duration_ms: ((Time.current - started) * 1000).round
    }
  rescue StandardError => e
    {
      id: kase['id'],
      intent: kase['intent'],
      input: kase['input'],
      error: "#{e.class}: #{e.message}",
      passed: false,
      checks: [{ name: 'runner', passed: false, detail: e.message }],
      tools_called: [],
      duration_ms: 0
    }
  end

  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def build_message_history(kase)
    history = Array(kase['history']).map { |m| { role: m['role'].to_sym, content: m['content'] } }
    history << { role: :user, content: kase['input'] }
    history
  end

  def call_runner(assistant, message_history, probe)
    service = Captain::Assistant::AgentRunnerService.new(
      assistant: assistant,
      callbacks: {
        on_tool_complete: ->(tool, result, _ctx) { probe.record(tool, result) }
      },
      source: 'eval'
    )
    service.generate_response(message_history: message_history)
  end

  def verify(kase, response, probe)
    response_text = response['response'].to_s
    [
      check_policy(kase, response, probe),
      check_expected_tools(kase, probe),
      check_forbidden_tools(kase, probe),
      check_required_phrases(kase, response_text),
      check_forbidden_phrases(kase, response_text),
      check_min_confidence(kase, probe)
    ].compact
  end

  def check_policy(kase, response, probe)
    expected = kase['expected_policy']
    return nil if expected.blank?

    actual = infer_policy(response, probe)
    { name: 'policy', passed: actual.to_s == expected.to_s, detail: "expected=#{expected} actual=#{actual}" }
  end

  def check_expected_tools(kase, probe)
    expected = Array(kase['expected_tools']).map(&:to_s)
    return nil if expected.empty?

    called = probe.tool_names
    missing = expected - called
    { name: 'expected_tools', passed: missing.empty?, detail: "missing=#{missing.inspect} called=#{called.inspect}" }
  end

  def check_forbidden_tools(kase, probe)
    forbidden = Array(kase['forbidden_tools']).map(&:to_s)
    return nil if forbidden.empty?

    hits = probe.tool_names & forbidden
    { name: 'forbidden_tools', passed: hits.empty?, detail: "violations=#{hits.inspect}" }
  end

  def check_required_phrases(kase, response_text)
    required = Array(kase['required_phrases'])
    return nil if required.empty?

    missing = required.reject { |phrase| response_text.include?(phrase.to_s) }
    { name: 'required_phrases', passed: missing.empty?, detail: "missing=#{missing.inspect}" }
  end

  def check_forbidden_phrases(kase, response_text)
    forbidden = Array(kase['forbidden_phrases'])
    return nil if forbidden.empty?

    hits = forbidden.select { |phrase| response_text.include?(phrase.to_s) }
    { name: 'forbidden_phrases', passed: hits.empty?, detail: "violations=#{hits.inspect}" }
  end

  def check_min_confidence(kase, probe)
    min = kase['min_confidence']
    return nil if min.blank?

    actual = probe.faq_result&.dig(:confidence) || probe.faq_result&.dig('confidence')
    actual_num = actual.to_f
    { name: 'min_confidence', passed: actual_num >= min.to_f, detail: "min=#{min} actual=#{actual_num}" }
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def infer_policy(response, probe)
    text = response['response'].to_s.strip
    tools = probe.tool_names
    return 'escalate' if text == 'conversation_handoff'
    return 'scenario_handoff' if tools.include?('handoff')
    return 'clarify' if text.end_with?('?') && !tools.intersect?(%w[booking_book_appointment yclients_book_appointment])
    return 'no_match' if text.blank?
    return 'answer' if text.match?(/\[\d+\]/) || tools.include?('faq_lookup')

    'answer'
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def write_report(assistant, results)
    FileUtils.mkdir_p(File.dirname(REPORT_PATH))
    File.write(REPORT_PATH, render_report(assistant, results))
    puts "📄 Report: #{REPORT_PATH}"
  end

  def render_report(assistant, results)
    lines = []
    lines << '# Captain eval report'
    lines << ''
    lines << "- Assistant: #{assistant.name} (##{assistant.id})"
    lines << "- Account: #{assistant.account.name} (##{assistant.account_id})"
    lines << "- Dataset: #{@dataset_path}"
    lines << "- Run at: #{Time.current.iso8601}"
    lines << "- Total: #{results.size}, Passed: #{results.count { |r| r[:passed] }}, Failed: #{results.count { |r| !r[:passed] }}"
    lines << ''
    results.each { |result| lines.concat(render_case(result)) }
    lines.join("\n")
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def render_case(result)
    header = "## #{result[:passed] ? '✅' : '❌'} #{result[:id]} — #{result[:intent]}"
    out = [header, '', "- Input: `#{result[:input]}`"]
    out << "- Duration: #{result[:duration_ms]} ms"
    out << "- Tools called: #{Array(result[:tools_called]).join(', ').presence || '(none)'}"
    out << "- FAQ confidence: #{result[:faq_confidence] || 'n/a'}"
    out << "- Policy: expected=#{result[:expected_policy] || 'n/a'} actual=#{result[:actual_policy] || 'n/a'}"
    out << "- Response: #{truncate(result[:response]&.dig('response'))}"
    out << "- Error: #{result[:error]}" if result[:error]
    out << ''
    out << '| Check | Passed | Detail |'
    out << '|---|---|---|'
    Array(result[:checks]).each { |c| out << "| #{c[:name]} | #{c[:passed] ? '✅' : '❌'} | #{c[:detail]} |" }
    out << ''
    out
  end

  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def truncate(text)
    return 'n/a' if text.blank?

    text.to_s.gsub(/\s+/, ' ').slice(0, 300)
  end

  def print_summary(results)
    passed = results.count { |r| r[:passed] }
    puts "\nCaptain eval: #{passed}/#{results.size} passed"
    results.reject { |r| r[:passed] }.each do |r|
      puts "  ❌ #{r[:id]}: #{Array(r[:checks]).reject { |c| c[:passed] }.map { |c| c[:name] }.join(', ')}"
    end
  end
end
# rubocop:enable Metrics/ClassLength

class RunProbe # rubocop:disable Style/OneClassPerFile
  attr_reader :tool_names, :faq_result

  def initialize
    @tool_names = []
    @faq_result = nil
  end

  def record(tool, result)
    name = normalize(tool)
    @tool_names << name
    @faq_result = result if name == 'faq_lookup' && result.is_a?(Hash)
  end

  private

  def normalize(tool)
    raw = if tool.is_a?(String)
            tool
          else
            tool.respond_to?(:name) ? tool.name : tool.to_s
          end
    raw.to_s.delete_prefix('captain--tools--').downcase
  end
end
