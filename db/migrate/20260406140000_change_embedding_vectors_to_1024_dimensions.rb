# frozen_string_literal: true

class ChangeEmbeddingVectorsTo1024Dimensions < ActiveRecord::Migration[7.1]
  def up
    truncate_embedding_tables!
    drop_embedding_indexes!
    change_embedding_dimensions!(1024)
    recreate_ivfflat_indexes!
  end

  def down
    truncate_embedding_tables!
    drop_embedding_indexes!
    change_embedding_dimensions!(1536)
    recreate_ivfflat_indexes!
  end

  private

  def truncate_embedding_tables!
    execute <<-SQL.squish
      TRUNCATE TABLE
        article_embeddings,
        captain_assistant_responses,
        captain_document_chunks
      RESTART IDENTITY
    SQL
  end

  def drop_embedding_indexes!
    remove_index :article_embeddings, name: 'index_article_embeddings_on_embedding', if_exists: true
    remove_index :captain_assistant_responses, name: 'vector_idx_knowledge_entries_embedding', if_exists: true
    remove_index :captain_document_chunks, name: 'index_captain_document_chunks_on_embedding', if_exists: true
  end

  def change_embedding_dimensions!(limit)
    change_column :article_embeddings, :embedding, :vector, limit: limit
    change_column :captain_assistant_responses, :embedding, :vector, limit: limit
    change_column :captain_document_chunks, :embedding, :vector, limit: limit
  end

  def recreate_ivfflat_indexes!
    add_index :article_embeddings, :embedding, using: :ivfflat, opclass: :vector_l2_ops
    add_index :captain_assistant_responses, :embedding, using: :ivfflat, name: 'vector_idx_knowledge_entries_embedding',
                                                        opclass: :vector_l2_ops
    add_index :captain_document_chunks, :embedding, using: :ivfflat, name: 'index_captain_document_chunks_on_embedding',
                                                    opclass: :vector_l2_ops
  end
end
