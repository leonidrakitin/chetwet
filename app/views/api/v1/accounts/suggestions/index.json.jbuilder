json.array! @suggestions do |suggestion|
  json.partial! 'api/v1/accounts/suggestions/suggestion',
                suggestion: suggestion,
                current_user_vote: @current_user_votes[suggestion.id]&.vote_type
end
