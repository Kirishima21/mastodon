# frozen_string_literal: true

class AddForeignKeyIndices < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :follows, :target_account_id, algorithm: :concurrently unless index_exists?(:follows, :target_account_id)
    add_index :blocks, :target_account_id, algorithm: :concurrently unless index_exists?(:blocks, :target_account_id)
    add_index :mutes, :target_account_id, algorithm: :concurrently unless index_exists?(:mutes, :target_account_id)
    add_index :notifications, :from_account_id, algorithm: :concurrently unless index_exists?(:notifications, :from_account_id)
    add_index :accounts, :moved_to_account_id, algorithm: :concurrently unless index_exists?(:accounts, :moved_to_account_id)
    add_index :statuses, :in_reply_to_account_id, algorithm: :concurrently unless index_exists?(:statuses, :in_reply_to_account_id)
    add_index :session_activations, :access_token_id, algorithm: :concurrently unless index_exists?(:session_activations, :access_token_id)
    add_index :oauth_access_grants, :resource_owner_id, algorithm: :concurrently unless index_exists?(:oauth_access_grants, :resource_owner_id)
  end
end
