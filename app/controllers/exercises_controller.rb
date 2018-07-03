class ExercisesController < ApplicationController
  before_action :set_exercise, only: [:show, :edit, :update, :destroy]

  def index
    @exercises = current_user.exercises
  end

  def new
    @exercise = current_user.exercises.new
  end

  def create
    @exercise = current_user.exercises.new(exercise_params)

    if @exercise.save
      redirect_to [current_user, @exercise], notice: 'Exercise has been created'
    else
      flash.now[:alert] = 'Exercise has not been created'
      render :new
    end
  end

  def show
  end

  def edit
  end

  def update
    if @exercise.update(exercise_params)
      redirect_to [current_user, @exercise], notice: 'Exercise has been updated'
    else
      flash.now[:alert] = 'Exercise has not been updated'
      render :edit
    end
  end

  def destroy
    @exercise.destroy
    redirect_to user_exercises_path(current_user), notice: 'Exercise has been deleted'
  end

  private

  def exercise_params
    params.require(:exercise).permit(:duration_in_min, :workout, :workout_date, :user_id)
  end

  def set_exercise
    @exercise = current_user.exercises.find(params[:id])
  end

end
