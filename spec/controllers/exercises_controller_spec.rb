require 'rails_helper'

RSpec.describe ExercisesController, type: :controller do
  # Devise test helpers for sign_in and sign_out
  include Devise::Test::ControllerHelpers

  # Define factories if not already globally available
  # (Ideally, these would be in spec/factories/)
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

  unless FactoryBot.factories.registered?(:exercise)
    FactoryBot.define do
      factory :exercise do
        association :user
        workout { "Running" }
        workout_date { Date.today }
        duration_in_min { 30 }
      end
    end
  end

  let(:owner) { create(:user, email: "owner@example.com") }
  let(:other_user) { create(:user, email: "other@example.com") }
  let!(:owner_exercise) { create(:exercise, user: owner, workout: "Owner's Treadmill Run") }

  # --- Authentication Tests ---
  shared_examples "requires sign in" do |action, http_method, params = {}|
    it "redirects to the sign-in page" do
      # Ensure no user is signed in for this example
      sign_out :user if controller.current_user

      case http_method
      when :get
        get action, params: params
      when :post
        post action, params: params
      when :put
        put action, params: params
      when :delete
        delete action, params: params
      end

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "Authentication" do
    context "when user is not signed in" do
      # Pass user_id for nested routes. The actual value doesn't matter much here as redirection should happen first.
      let(:base_params) { { user_id: owner.id } }
      let(:exercise_params_with_id) { base_params.merge(id: owner_exercise.id) }

      include_examples "requires sign in", :index, :get, -> { { user_id: owner.id } }
      include_examples "requires sign in", :show, :get, -> { exercise_params_with_id }
      include_examples "requires sign in", :new, :get, -> { { user_id: owner.id } }
      include_examples "requires sign in", :edit, :get, -> { exercise_params_with_id }

      it "redirects create to sign-in page" do
        post :create, params: { user_id: owner.id, exercise: attributes_for(:exercise) }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects update to sign-in page" do
        put :update, params: { user_id: owner.id, id: owner_exercise.id, exercise: { workout: "Updated Workout" } }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects destroy to sign-in page" do
        delete :destroy, params: { user_id: owner.id, id: owner_exercise.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # --- Authorization Tests (Ownership) ---
  shared_examples "prevents access to other user's exercise" do |action, http_method|
    it "raises RecordNotFound or redirects" do
      sign_in other_user # Sign in as a different user

      # Expect ActiveRecord::RecordNotFound because set_exercise uses current_user.exercises.find
      expect {
        case http_method
        when :get
          get action, params: { user_id: owner.id, id: owner_exercise.id }
        when :put
          put action, params: { user_id: owner.id, id: owner_exercise.id, exercise: { workout: "Attempted Update" } }
        when :delete
          delete action, params: { user_id: owner.id, id: owner_exercise.id }
        end
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Authorization" do
    context "when trying to access another user's exercise" do
      include_examples "prevents access to other user's exercise", :show, :get
      include_examples "prevents access to other user's exercise", :edit, :get
      include_examples "prevents access to other user's exercise", :update, :put
      include_examples "prevents access to other user's exercise", :destroy, :delete
    end
  end


  # --- RESTful Actions Tests (when authenticated as owner) ---
  context "when user is signed in as the owner" do
    before do
      sign_in owner
    end

    describe "GET #index" do
      let!(:exercise2) { create(:exercise, user: owner, workout: "Owner's Cycling") }
      let!(:other_user_exercise) { create(:exercise, user: other_user, workout: "Other's Yoga") }


      before { get :index, params: { user_id: owner.id } }

      it "renders the index template" do
        expect(response).to render_template(:index)
      end

      it "assigns the current user's exercises to @exercises" do
        # The controller uses current_user.exercises, so it should be scoped.
        # Default scope on Exercise model might affect this too (last 7 days).
        # Assuming factory creates recent exercises for simplicity here.
        expect(assigns(:exercises)).to match_array([owner_exercise, exercise2])
        expect(assigns(:exercises)).not_to include(other_user_exercise)
      end

      it "assigns current_user.friends to @friends" do
        # Add some friends for the owner to test this assignment
        friend1 = create(:user, email: "friend1@example.com")
        create(:friendship, user: owner, friend: friend1)
        get :index, params: { user_id: owner.id } # Re-request to update @friends
        expect(assigns(:friends)).to eq([friend1])
      end
    end

    describe "GET #show" do
      before { get :show, params: { user_id: owner.id, id: owner_exercise.id } }

      it "renders the show template" do
        expect(response).to render_template(:show)
      end

      it "assigns the correct exercise to @exercise" do
        expect(assigns(:exercise)).to eq(owner_exercise)
      end
    end

    describe "GET #new" do
      before { get :new, params: { user_id: owner.id } }

      it "renders the new template" do
        expect(response).to render_template(:new)
      end

      it "assigns a new Exercise instance to @exercise, associated with the current user" do
        expect(assigns(:exercise)).to be_a_new(Exercise)
        expect(assigns(:exercise).user).to eq(owner)
      end
    end

    describe "POST #create" do
      let(:valid_attributes) { { duration_in_min: 60, workout: "Weightlifting", workout_date: Date.today } }
      let(:invalid_attributes) { { duration_in_min: 0, workout: "", workout_date: nil } }

      context "with valid parameters" do
        it "creates a new Exercise for the current user" do
          expect {
            post :create, params: { user_id: owner.id, exercise: valid_attributes }
          }.to change(owner.exercises, :count).by(1)
        end

        it "redirects to the created exercise (nested under user)" do
          post :create, params: { user_id: owner.id, exercise: valid_attributes }
          # The redirect is `[current_user, @exercise]` which translates to user_exercise_path(owner, assigns(:exercise))
          expect(response).to redirect_to(user_exercise_path(owner, assigns(:exercise)))
        end

        it "sets a success flash message" do
          post :create, params: { user_id: owner.id, exercise: valid_attributes }
          expect(flash[:notice]).to eq("Exercise has been created")
        end
      end

      context "with invalid parameters" do
        it "does not create a new Exercise" do
          expect {
            post :create, params: { user_id: owner.id, exercise: invalid_attributes }
          }.not_to change(Exercise, :count)
        end

        it "re-renders the 'new' template" do
          post :create, params: { user_id: owner.id, exercise: invalid_attributes }
          expect(response).to render_template(:new)
        end

        it "sets an alert flash message" do
          post :create, params: { user_id: owner.id, exercise: invalid_attributes }
          expect(flash.now[:alert]).to eq("Exercise has not been created")
        end
      end
    end

    describe "GET #edit" do
      before { get :edit, params: { user_id: owner.id, id: owner_exercise.id } }

      it "renders the edit template" do
        expect(response).to render_template(:edit)
      end

      it "assigns the correct exercise to @exercise" do
        expect(assigns(:exercise)).to eq(owner_exercise)
      end
    end

    describe "PUT #update" do
      let(:new_attributes) { { workout: "Power Yoga", duration_in_min: 75 } }
      let(:invalid_attributes) { { workout: "", duration_in_min: 0 } }

      context "with valid parameters" do
        before do
          put :update, params: { user_id: owner.id, id: owner_exercise.id, exercise: new_attributes }
          owner_exercise.reload
        end

        it "updates the attributes of the exercise" do
          expect(owner_exercise.workout).to eq("Power Yoga")
          expect(owner_exercise.duration_in_min).to eq(75)
        end

        it "redirects to the exercise (nested under user)" do
          expect(response).to redirect_to(user_exercise_path(owner, owner_exercise))
        end

        it "sets a success flash message" do
          expect(flash[:notice]).to eq("Exercise has been updated")
        end
      end

      context "with invalid parameters" do
        before do
          put :update, params: { user_id: owner.id, id: owner_exercise.id, exercise: invalid_attributes }
          owner_exercise.reload # Ensure we check against the original or reloaded attributes
        end

        it "does not update the exercise" do
          expect(owner_exercise.workout).not_to eq("")
          expect(owner_exercise.duration_in_min).not_to eq(0)
          expect(owner_exercise.workout).to eq("Owner's Treadmill Run") # Original value
        end

        it "re-renders the 'edit' template" do
          expect(response).to render_template(:edit)
        end

        it "sets an alert flash message" do
          expect(flash.now[:alert]).to eq("Exercise has not been updated")
        end
      end
    end

    describe "DELETE #destroy" do
      it "deletes the exercise" do
        expect {
          delete :destroy, params: { user_id: owner.id, id: owner_exercise.id }
        }.to change(owner.exercises, :count).by(-1)
      end

      it "redirects to the user's exercises path" do
        delete :destroy, params: { user_id: owner.id, id: owner_exercise.id }
        expect(response).to redirect_to(user_exercises_path(owner))
      end

      it "sets a success flash message" do
        delete :destroy, params: { user_id: owner.id, id: owner_exercise.id }
        expect(flash[:notice]).to eq("Exercise has been deleted")
      end
    end
  end
end
