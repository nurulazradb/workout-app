require 'rails_helper'

RSpec.describe Exercise, type: :model do
  # Assume a User factory is available, e.g., from spec/factories/users.rb
  # FactoryBot.define do
  #   factory :user do
  #     first_name { "Test" }
  #     sequence(:last_name) { |n| "User#{n}" }
  #     sequence(:email) { |n| "testuser#{n}@example.com" }
  #     password { "password123" }
  #     password_confirmation { "password123" }
  #   end
  # end

  # Define a factory for Exercise
  FactoryBot.define do
    factory :exercise do
      association :user # Associates with a User factory
      workout { "Running" }
      workout_date { Date.today }
      duration_in_min { 30 }
    end
  end

  let(:user) { create(:user) } # Helper to create a user for exercises

  describe "validations" do
    it "is valid with valid attributes" do
      exercise = build(:exercise, user: user)
      expect(exercise).to be_valid
    end

    it "is not valid without duration_in_min" do
      exercise = build(:exercise, user: user, duration_in_min: nil)
      expect(exercise).not_to be_valid
      expect(exercise.errors[:duration_in_min]).to include("is not a number")
    end

    it "is not valid if duration_in_min is 0" do
      exercise = build(:exercise, user: user, duration_in_min: 0)
      expect(exercise).not_to be_valid
      expect(exercise.errors[:duration_in_min]).to include("must be greater than 0")
    end

    it "is not valid if duration_in_min is negative" do
      exercise = build(:exercise, user: user, duration_in_min: -10)
      expect(exercise).not_to be_valid
      expect(exercise.errors[:duration_in_min]).to include("must be greater than 0")
    end

    it "is not valid without a workout (workout_details)" do
      exercise = build(:exercise, user: user, workout: nil)
      expect(exercise).not_to be_valid
      expect(exercise.errors[:workout_details]).to include("can't be blank")
    end

    it "is not valid without a workout_date (activity_date)" do
      exercise = build(:exercise, user: user, workout_date: nil)
      expect(exercise).not_to be_valid
      expect(exercise.errors[:activity_date]).to include("can't be blank")
    end
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "alias attributes" do
    let(:exercise) { build(:exercise, workout: "Weightlifting", workout_date: Date.yesterday) }

    it "aliases workout to workout_details" do
      expect(exercise.workout_details).to eq("Weightlifting")
      exercise.workout_details = "Yoga"
      expect(exercise.workout).to eq("Yoga")
    end

    it "aliases workout_date to activity_date" do
      expect(exercise.activity_date).to eq(Date.yesterday)
      new_date = Date.today - 2.days
      exercise.activity_date = new_date
      expect(exercise.workout_date).to eq(new_date)
    end
  end

  describe "default_scope" do
    let!(:user_for_scope) { create(:user) } # Use a separate user for scope tests to avoid interference
    let!(:exercise1_recent) { create(:exercise, user: user_for_scope, workout_date: Date.today, workout: "Recent 1") }
    let!(:exercise2_older) { create(:exercise, user: user_for_scope, workout_date: 8.days.ago, workout: "Older") }
    let!(:exercise3_recent_earlier) { create(:exercise, user: user_for_scope, workout_date: 1.day.ago, workout: "Recent 2") }
    let!(:exercise4_ancient) { create(:exercise, user: user_for_scope, workout_date: 10.days.ago, workout: "Ancient" ) }
    let!(:exercise5_recent_latest) { create(:exercise, user: user_for_scope, workout_date: Time.zone.now, workout: "Recent Latest") }


    it "only includes exercises from the last 7 days" do
      recent_exercises = user_for_scope.exercises # Default scope is applied here
      expect(recent_exercises).to include(exercise1_recent, exercise3_recent_earlier, exercise5_recent_latest)
      expect(recent_exercises).not_to include(exercise2_older, exercise4_ancient)
    end

    it "orders exercises by workout_date descending" do
      recent_exercises = user_for_scope.exercises # Default scope is applied here
      # workout_date includes time, so direct comparison might be tricky if time part is not set consistently.
      # Let's ensure factory sets dates consistently or compare only date part if needed.
      # For this test, assuming workout_date is precise enough for ordering.
      expect(recent_exercises.map(&:workout)).to eq([
        exercise5_recent_latest.workout, # Today (or now)
        exercise1_recent.workout,      # Today
        exercise3_recent_earlier.workout # Yesterday
      ])
    end

    context "when accessing exercises directly on the class" do
       # Create exercises with specific dates for thorough testing
      let!(:exercise_today_scoped) { create(:exercise, workout_date: Date.today, workout: "Scoped Today", user: user_for_scope) }
      let!(:exercise_yesterday_scoped) { create(:exercise, workout_date: 1.day.ago, workout: "Scoped Yesterday", user: user_for_scope) }
      let!(:exercise_six_days_ago_scoped) { create(:exercise, workout_date: 6.days.ago, workout: "Scoped Six Days Ago", user: user_for_scope) }
      # This exercise should be out of scope
      let!(:exercise_eight_days_ago_unscoped) { create(:exercise, workout_date: 8.days.ago, workout: "Unscoped Eight Days Ago", user: user_for_scope, duration_in_min: 10) } # Need a valid duration

      it "includes only exercises within the last 7 days" do
        expect(Exercise.all).to include(exercise_today_scoped, exercise_yesterday_scoped, exercise_six_days_ago_scoped)
        expect(Exercise.all).not_to include(exercise_eight_days_ago_unscoped)
      end

      it "orders exercises by workout_date descending" do
        # Fetching all exercises (which applies default scope) for the specific user
        # to ensure we are only dealing with this user's exercises for ordering.
        # Or, if testing Exercise.all, ensure other users' exercises don't interfere.
        # For simplicity, let's assume these are the only relevant exercises or filter by user if needed.
        # For Exercise.all, it will include other users' recent exercises too if any.
        # The previous tests for user.exercises are more specific to a user context.
        # This tests the direct class-level default scope.
        # Re-create exercises with distinct dates to ensure order
        user_for_all = create(:user, email: "allscopeuser@example.com")
        e1 = create(:exercise, user: user_for_all, workout_date: 1.day.ago)
        e2 = create(:exercise, user: user_for_all, workout_date: Date.today)
        e3 = create(:exercise, user: user_for_all, workout_date: 2.days.ago)
        create(:exercise, user: user_for_all, workout_date: 8.days.ago) # out of scope

        # Re-query Exercise.all to get fresh results with the default scope
        all_scoped_exercises = Exercise.where(user: user_for_all).to_a # Apply user filter to simplify order check
        expect(all_scoped_exercises.map(&:workout_date)).to eq([e2.workout_date, e1.workout_date, e3.workout_date])
      end
    end

    it "works correctly when no exercises are present for a user" do
        new_user = create(:user, email: "newscopeuser@example.com")
        expect(new_user.exercises).to be_empty
    end

    it "works correctly when all exercises are outside the 7-day window for a user" do
        user_with_old_exercises = create(:user, email: "oldscopeuser@example.com")
        create(:exercise, user: user_with_old_exercises, workout_date: 10.days.ago)
        create(:exercise, user: user_with_old_exercises, workout_date: 15.days.ago)
        expect(user_with_old_exercises.exercises).to be_empty
    end
  end

  # No other public instance or class methods identified in the model snippet provided,
  # other than standard Rails model methods, aliases, validations, and scopes.
end
