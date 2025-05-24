require 'rails_helper'

RSpec.describe Friendship, type: :model do
  # Assume a User factory is available, e.g., from spec/factories/users.rb
  # If not globally available, define it here for self-containment of this spec file,
  # though ideally it would be in a separate factory file.
  unless FactoryBot.factories.registered?(:user)
    FactoryBot.define do
      factory :user do
        first_name { "Test" }
        sequence(:last_name) { |n| "User#{n}" }
        sequence(:email) { |n| "testuser#{n}@example.com" }
        password { "password123" }
        password_confirmation { "password123" }
      end
    end
  end

  # Define a factory for Friendship
  FactoryBot.define do
    factory :friendship do
      association :user
      association :friend, factory: :user # Ensures friend is also a User instance
    end
  end

  let(:user1) { create(:user) }
  let(:user2) { create(:user) }

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:friend).class_name('User') }
  end

  describe "validations and basic functionality" do
    it "is valid with a user and a friend" do
      friendship = build(:friendship, user: user1, friend: user2)
      expect(friendship).to be_valid
    end

    it "is not valid without a user" do
      friendship = build(:friendship, user: nil, friend: user2)
      expect(friendship).not_to be_valid
      # Rails 5+ automatically adds a presence validation for belongs_to associations.
      # The error message might vary slightly based on Rails version.
      expect(friendship.errors[:user]).to include("must exist")
    end

    it "is not valid without a friend" do
      friendship = build(:friendship, user: user1, friend: nil)
      expect(friendship).not_to be_valid
      expect(friendship.errors[:friend]).to include("must exist")
    end

    it "can be created successfully" do
      expect {
        Friendship.create!(user: user1, friend: user2)
      }.to change(Friendship, :count).by(1)
    end

    it "prevents a user from friending themselves directly through this model (if such a validation were added)" do
      # Note: The current Friendship model does not have a validation to prevent a user from friending themselves.
      # If such a validation (e.g., `validates :user_id, exclusion: { in: ->(f) { [f.friend_id] } }`) were added,
      # this test would be relevant. For now, it just documents a potential scenario.
      # friendship_with_self = build(:friendship, user: user1, friend: user1)
      # expect(friendship_with_self).not_to be_valid # This would fail with current model
      # For the current model, it *is* valid to create such a friendship,
      # though it might be undesirable from a business logic perspective (often handled at controller level or with custom validation).
      friendship_with_self = build(:friendship, user: user1, friend: user1)
      expect(friendship_with_self).to be_valid # Based on the current model definition
    end

    it "allows multiple friendships for the same user with different friends" do
      user3 = create(:user)
      create(:friendship, user: user1, friend: user2)
      friendship2 = build(:friendship, user: user1, friend: user3)
      expect(friendship2).to be_valid
      expect { friendship2.save! }.to change(Friendship, :count).by(1)
    end

    it "allows a user to be a friend in multiple friendships" do
      user3 = create(:user)
      create(:friendship, user: user1, friend: user2)
      friendship2 = build(:friendship, user: user3, friend: user2)
      expect(friendship2).to be_valid
      expect { friendship2.save! }.to change(Friendship, :count).by(1)
    end

    # The model itself doesn't have a uniqueness validation on [:user_id, :friend_id].
    # This means duplicate friendships *can* be created at the model level.
    # Such uniqueness is often enforced at the database level or with a model validation.
    # The following test demonstrates current behavior (allows duplicates).
    it "allows duplicate friendships (by default, unless a uniqueness validation is added)" do
      create(:friendship, user: user1, friend: user2)
      duplicate_friendship = build(:friendship, user: user1, friend: user2)
      expect(duplicate_friendship).to be_valid # This is true for the current model
      expect { duplicate_friendship.save! }.to change(Friendship, :count).by(1)
    end
  end

  # No custom public methods were identified in the Friendship model snippet.
  # If any were added, tests for them would go here.
end
