require 'administrate/field/base'

class LlmUsageStatsField < Administrate::Field::Base
  def to_s
    return 'No data' if data.blank?

    summary = data
    stats_cards(summary) + feature_details(summary[:by_feature])
  end

  private

  def stats_cards(summary)
    <<~HTML
      <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin: 16px 0;">
        #{stat_card('Messages Today', number_with_delimiter(summary[:today_requests]), '#1e293b')}
        #{stat_card('Tokens Today', number_with_delimiter(summary[:today_tokens]), '#1e293b')}
        #{stat_card('Cost Today', format('$%.4f', summary[:today_cost]), '#059669')}
        #{stat_card('Total Cost', format('$%.4f', summary[:total_cost]), '#0284c7')}
      </div>
    HTML
  end

  def stat_card(label, value, color)
    <<~HTML
      <div style="background: #f8fafc; padding: 16px; border-radius: 8px; border: 1px solid #e2e8f0;">
        <div style="font-size: 12px; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px;">#{label}</div>
        <div style="font-size: 24px; font-weight: 600; color: #{color}; margin-top: 4px;">#{value}</div>
      </div>
    HTML
  end

  def feature_details(by_feature)
    <<~HTML
      <details style="margin-top: 16px;">
        <summary style="cursor: pointer; font-weight: 500; color: #475569;">By Feature</summary>
        <table style="width: 100%; margin-top: 8px; border-collapse: collapse;">
          <thead>
            <tr style="background: #f1f5f9;">
              <th style="padding: 8px; text-align: left; border-bottom: 2px solid #e2e8f0;">Feature</th>
              <th style="padding: 8px; text-align: right; border-bottom: 2px solid #e2e8f0;">Requests</th>
              <th style="padding: 8px; text-align: right; border-bottom: 2px solid #e2e8f0;">Tokens</th>
              <th style="padding: 8px; text-align: right; border-bottom: 2px solid #e2e8f0;">Cost</th>
            </tr>
          </thead>
          <tbody>
            #{feature_rows(by_feature)}
          </tbody>
        </table>
      </details>
    HTML
  end

  def feature_rows(by_feature)
    return '<tr><td colspan="4" style="padding: 8px; text-align: center; color: #94a3b8;">No data</td></tr>' if by_feature.blank?

    by_feature.map do |feature, stats|
      <<~HTML
        <tr>
          <td style="padding: 8px; border-bottom: 1px solid #e2e8f0;">#{feature.humanize}</td>
          <td style="padding: 8px; text-align: right; border-bottom: 1px solid #e2e8f0;">#{number_with_delimiter(stats[:total_requests])}</td>
          <td style="padding: 8px; text-align: right; border-bottom: 1px solid #e2e8f0;">#{number_with_delimiter(stats[:total_tokens])}</td>
          <td style="padding: 8px; text-align: right; border-bottom: 1px solid #e2e8f0;">$#{format('%.4f', stats[:total_cost_usd])}</td>
        </tr>
      HTML
    end.join
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
