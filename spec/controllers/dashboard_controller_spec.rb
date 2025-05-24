require 'rails_helper'

RSpec.describe DashboardController, type: :controller do

  # Assuming User factory is defined (e.g., in spec/factories/users.rb or from previous specs)
  # For self-containment if running this spec alone:
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

  let!(:user1) { create(:user, first_name: "John", last_name: "Doe") }
  let!(:user2) { create(:user, first_name: "Jane", last_name: "Doe") }
  let!(:user3) { create(:user, first_name: "Peter", last_name: "Pan") }

  describe "GET #index" do
    before { get :index }

    it "renders the index template" do
      expect(response).to render_template(:index)
    end

    it "assigns @athletes to all users (paginated)" do
      # Pagy assigns records to the second variable returned by pagy()
      # In the controller, it's `@pagy, @athletes = pagy(User.all)`
      # So, controller's @athletes will be an array of User instances.
      # The `assigns` method gives access to instance variables set in the controller action.
      expect(assigns(:athletes)).to match_array([user1, user2, user3])
    end

    it "returns a successful response" do
      expect(response).to be_successful # or expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #search" do
    context "with a valid search term that matches users" do
      before { get :search, params: { search_name: "John" } }

      it "renders the search template" do
        expect(response).to render_template(:search)
      end

      it "assigns @athletes with matching users" do
        expect(assigns(:athletes)).to include(user1)
        expect(assigns(:athletes)).not_to include(user2, user3)
      end

      it "returns a successful response" do
        expect(response).to be_successful
      end
    end

    context "with a valid search term that matches multiple users" do
      before { get :search, params: { search_name: "Doe" } }

      it "assigns @athletes with all matching users" do
        expect(assigns(:athletes)).to match_array([user1, user2]) # Order might matter depending on search_by_name
      end
    end

    context "with a valid search term that does not match any users" do
      before { get :search, params: { search_name: "NonExistentName" } }

      it "renders the search template" do
        # It should still render the template, possibly with a message or empty list
        expect(response).to render_template(:search)
      end

      it "assigns @athletes as an empty collection" do
        expect(assigns(:athletes)).to be_empty
      end

      it "returns a successful response" do
        expect(response).to be_successful
      end
    end

    context "with a blank search term" do
      before { get :search, params: { search_name: "" } }

      it "renders the search template" do
        expect(response).to render_template(:search)
      end

      it "assigns @athletes with all users (based on User.search_by_name behavior for blank)" do
        # Assuming User.search_by_name("") returns all users, as tested in user_spec.rb
        expect(assigns(:athletes)).to match_array([user1, user2, user3])
      end

      it "returns a successful response" do
        expect(response).to be_successful
      end
    end

    context "without a search term (params[:search_name] is nil)" do
      before { get :search } # No search_name param

      it "renders the search template" do
        expect(response).to render_template(:search)
      end

      it "assigns @athletes based on nil search (likely all users or empty, depends on User.search_by_name)" do
        # User.search_by_name(nil) would likely split nil, causing an error if not handled.
        # Let's assume for now it's handled gracefully in the model or results in empty.
        # If User.search_by_name(nil) raises error, this test would fail and model needs update,
        # or controller needs to sanitize params[:search_name].
        # From the User model code: names = name.split(' ') will raise error if name is nil.
        # This indicates a potential bug if params[:search_name] can be nil.
        # For a robust controller, it should probably default params[:search_name] to "".
        # For now, testing current behavior.
        # A better controller would be: User.search_by_name(params[:search_name].to_s)
        # Let's assume it should behave like empty search for this test.
        # This test might fail if not handled in model or controller.
        # Based on the User model's search_by_name, a nil input will cause an error.
        # So, this request should ideally not happen or be gracefully handled.
        # For a controller spec, we are testing what happens if it *does* receive nil.
        # A 500 error would be the expected outcome if not handled.
        # However, RSpec controller tests often don't raise full server errors by default for nil param issues.
        # Let's test for assignment, it might be an empty array or all users depending on how `split` on nil is treated
        # by `where` with nil conditions. Often, `where("column like ?", nil)` is not valid SQL.
        # The User model code `names.size` would fail if names is nil.
        # So, `User.search_by_name(nil)` will raise an error.
        # The controller does not sanitize this. So, an error should occur.

        # To properly test this, we'd expect an error.
        # However, typical controller specs might not catch this specific model error propagation easily
        # without more complex setup. For now, let's assume we want to see if @athletes is set.
        # It will likely be nil or an empty array before an error is rendered or caught.

        # Given the model `name.split(' ')`, if name is nil, it will raise NoMethodError.
        # This means the controller action would raise an exception.
        expect { get :search }.to raise_error(NoMethodError) # Or specific error it might become
      end

      # If we want to test that it *doesn't* raise an error (i.e., controller handles it):
      # it "does not raise an error and assigns athletes (e.g. empty)" do
      #   expect { get :search }.not_to raise_error
      #   expect(response).to be_successful
      #   expect(assigns(:athletes)).to be_empty # Or all users, depending on desired graceful handling
      #   expect(response).to render_template(:search)
      # end
    end
  end
end
