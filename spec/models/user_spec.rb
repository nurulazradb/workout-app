require 'rails_helper'

RSpec.describe User, type: :model do
  # Devise modules automatically test for presence and uniqueness of email, and presence of password.
  # We will focus on custom validations, associations, and methods.

  describe "validations" do
    let(:user) { build(:user) } # Using FactoryBot's build method

    it "is valid with valid attributes" do
      expect(user).to be_valid
    end

    it "is not valid without a first_name" do
      user.first_name = nil
      expect(user).not_to be_valid
      expect(user.errors[:first_name]).to include("can't be blank")
    end

    it "is not valid without a last_name" do
      user.last_name = nil
      expect(user).not_to be_valid
      expect(user.errors[:last_name]).to include("can't be blank")
    end
  end

  describe "associations" do
    it { should have_many(:exercises) }
    it { should have_many(:friendships) }
    it { should have_many(:friends).through(:friendships).class_name('User') }
  end

  describe "public methods" do
    let(:user1) { create(:user, first_name: "John", last_name: "Doe") } # Using FactoryBot's create method
    let(:user2) { create(:user, first_name: "Jane", last_name: "Doe") }
    let(:user3) { create(:user, first_name: "Peter", last_name: "Pan") }

    describe "#full_name" do
      it "returns the full name of the user" do
        expect(user1.full_name).to eq("John Doe")
      end
    end

    describe ".search_by_name" do
      before do
        # Ensure users are created for search
        user1
        user2
        user3
      end

      context "when searching with a single name" do
        it "returns users matching first or last name" do
          expect(User.search_by_name("John")).to include(user1)
          expect(User.search_by_name("John")).not_to include(user3)
        end

        it "returns users matching last name" do
          expect(User.search_by_name("Doe")).to include(user1, user2)
          expect(User.search_by_name("Doe")).not_to include(user3)
        end

         it "is case-insensitive" do
          expect(User.search_by_name("john")).to include(user1)
          expect(User.search_by_name("doe")).to include(user1, user2)
        end
      end

      context "when searching with two names" do
        it "returns users matching combinations of first and last names" do
          expect(User.search_by_name("John Doe")).to include(user1)
          expect(User.search_by_name("Jane Doe")).to include(user2)
          expect(User.search_by_name("Doe John")).to include(user1) # Order shouldn't matter for the parts
        end

        it "does not return users that don't match" do
          expect(User.search_by_name("John Pan")).not_to include(user1, user3)
        end
      end

      context "when no name is provided" do
        # The current implementation might return all users or raise an error depending on DB.
        # Let's assume it should return an empty relation if the input is blank.
        # This test might need adjustment based on desired behavior for blank search.
        it "returns an empty collection or all users if name is blank (depending on implementation)" do
          # Based on the current code, it will likely try `where('first_name like ? or last_name like ?', "%%", "%%")`
          # which would return all users. If specific behavior for blank is needed, the method should be updated.
          # For now, let's test the existing behavior.
           expect(User.search_by_name("")).to match_array([user1, user2, user3])
        end
      end

       context "when name is not found" do
        it "returns an empty collection" do
          expect(User.search_by_name("NonExistentName")).to be_empty
        end
      end
    end

    describe "#follows_or_same?" do
      let!(:friendship) { create(:friendship, user: user1, friend: user2) }

      it "returns true if the user is the same as the new_friend" do
        expect(user1.follows_or_same?(user1)).to be true
      end

      it "returns true if the user follows the new_friend" do
        expect(user1.follows_or_same?(user2)).to be true
      end

      it "returns false if the user does not follow the new_friend and is not the same" do
        expect(user1.follows_or_same?(user3)).to be false
      end
    end

    describe "#current_friendship" do
      context "when a friendship exists" do
        let!(:friendship) { create(:friendship, user: user1, friend: user2) }

        it "returns the friendship object" do
          expect(user1.current_friendship(user2)).to eq(friendship)
        end
      end

      context "when a friendship does not exist" do
        it "returns nil" do
          expect(user1.current_friendship(user3)).to be_nil
        end
      end
    end
  end
end

# Helper to define factories for User and Friendship if they don't exist
# This is a simplified version. Ideally, this would be in spec/factories/users.rb and spec/factories/friendships.rb
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

unless FactoryBot.factories.registered?(:friendship)
  FactoryBot.define do
    factory :friendship do
      association :user
      association :friend, factory: :user # Ensures friend is also a User
    end
  end
end
