class NotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_note, only: [:show, :edit, :update, :destroy]
  # before_action :authorize_user, only: [:show, :edit, :update, :destroy]

  require 'faker'

  # GET /notes
  # GET /notes.json
  def index
    @notes = Note.where(user_id: current_user.id)
    if params[:q]
      @notes = @notes.where('lower(title) LIKE :q OR lower(body) LIKE :q', q: "%#{params[:q].downcase}%")
    end
  end

  # GET /notes/1
  # GET /notes/1.json
  def show
    return render json: {:error => "unauthorized"}, status: :unauthorized unless @note.user_id == current_user.id
  end

  # GET /notes/new
  def new
    @note = Note.new
    @users = User.where.not(id: current_user.id)
  end

  # GET /notes/1/edit
  def edit
    return render json: {:error => "unauthorized"}, status: :unauthorized unless @note.user_id == current_user.id

    @users = User.where.not(id: current_user.id)
  end

  # POST /notes
  # POST /notes.json
  def create
    @note = Note.new(note_params)
    @note.uuid = SecureRandom.uuid
    @note.password = Faker::Internet.password

    respond_to do |format|
      if @note.save
        if create_collaborations
          format.html { redirect_to @note, notice: 'Note was successfully created.' }
          format.json { render :show, status: :created, location: @note }
        else
          @note.destroy
          @note.errors << 'undefined collaborations user!'
          format.html { render :new }
          format.json { render json: @note.errors, status: :unprocessable_entity }
        end
      else
        format.html { render :new }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /notes/1
  # PATCH/PUT /notes/1.json
  def update
    return render json: {:error => "unauthorized"}, status: :unauthorized unless @note.user_id == current_user.id
    
    respond_to do |format|
      if @note.update(note_params)
        Collaboration.where(note_id: @note.id).update_all(can_edit: true) if params[:can_edit]

        format.html { redirect_to @note, notice: 'Note was successfully updated.' }
        format.json { render :show, status: :ok, location: @note }
      else
        format.html { render :edit }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /notes/1
  # DELETE /notes/1.json
  def destroy
    return render json: {:error => "unauthorized"}, status: :unauthorized unless @note.user_id == current_user.id

    @note.destroy
    respond_to do |format|
      format.html { redirect_to notes_url, notice: 'Note was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_note
      @note = Note.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def note_params
      params.require(:note).permit(:title, :body, :user_id, :collaborations)
    end

    def create_collaborations
      if params[:collaborations]
        can_edit = true if params[:can_edit]
        params[:collaborations].each do |collaboration|
          user = User.find(collaboration)
          Collaboration.create!(note_id: @note.id, can_edit: can_edit || false, user_id: user.id) unless user.nil?
          return false if user.nil?
        end
      else
        true
      end
    end

    def authorize_user
      return render json: {:error => "unauthorized"}, status: :unauthorized unless @note.user_id == current_user.id
    end
end
