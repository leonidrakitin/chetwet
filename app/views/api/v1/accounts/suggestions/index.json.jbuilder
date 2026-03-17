json.array! @suggestions do |suggestion|
  json.id suggestion.id
  json.title suggestion.title
  json.description suggestion.description
  json.status suggestion.status
  json.tags suggestion.tags
  json.upvotes_count suggestion.upvotes_count
  json.downvotes_count suggestion.downvotes_count
  json.created_at suggestion.created_at
  json.updated_at suggestion.updated_at

  json.user do
    json.id suggestion.user.id
    json.name suggestion.user.name
    json.avatar_url suggestion.user.avatar_url
  end

  current_vote = @current_user_votes[suggestion.id]
  json.current_user_vote current_vote&.vote_type
end
