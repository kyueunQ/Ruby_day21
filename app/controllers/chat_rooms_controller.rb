class ChatRoomsController < ApplicationController
  before_action :set_chat_room, only: [:show, :edit, :update, :destroy, :user_admit_room, :chat, :user_exit_room]
  before_action :authenticate_user!, except: [:index]

  # GET /chat_rooms
  # GET /chat_rooms.json
  def index
    @chat_rooms = ChatRoom.all
  end

  # GET /chat_rooms/1
  # GET /chat_rooms/1.json
  def show
  end

  # GET /chat_rooms/new
  def new
    @chat_room = ChatRoom.new
  end

  # GET /chat_rooms/1/edit
  def edit
  end

  # POST /chat_rooms
  # POST /chat_rooms.json
  def create
    @chat_room = ChatRoom.new(chat_room_params)
    # 그러나 row가 만들어진 것은 아님 (admission에는생성x)
    @chat_room.master_id = current_user.email
    respond_to do |format|
      if @chat_room.save
        # ChatRoom에서 하나의 방을 가르키는 'chat_room'에
        @chat_room.user_admit_room(current_user)
        format.html { redirect_to @chat_room, notice: 'Chat room was successfully created.' }
        format.json { render :show, status: :created, location: @chat_room }
      else
        format.html { render :new }
        format.json { render json: @chat_room.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /chat_rooms/1
  # PATCH/PUT /chat_rooms/1.json
  def update
    respond_to do |format|
      if @chat_room.update(chat_room_params)
        format.html { redirect_to @chat_room, notice: 'Chat room was successfully updated.' }
        format.json { render :show, status: :ok, location: @chat_room }
      else
        format.html { render :edit }
        format.json { render json: @chat_room.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /chat_rooms/1
  # DELETE /chat_rooms/1.json
  def destroy
    @chat_room.destroy
    respond_to do |format|
      format.html { redirect_to chat_rooms_url, notice: 'Chat room was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def user_admit_room
    # 현재 유저가 있는 방에서 join 버튼을 눌렀을 때 동작하는 액션
    # model method에서 넘어온 친구
    
    # 이미 조인한 유저라면
    # alert로 이미 참가한 방입니다 라고 띄우기
    # 아닐 경우 참여 시킨다
    
    # 2가지 방법
    # 1. 유저가 참가하고 있느 방의 목록 중에 이 방이 포함되어 있나?
    #current_user.chat_rooms.where(id: params[:id])
    #current_user.chat_rooms.inclue? (@chat_room)
    # 2. 방에 참가하고 있는 유저들 중에 이 유저가 있는가?
    # @chat_room.users.inclue? (@chat_room.users)
    # if @chat_room.users.inclue? (current_user)
    if current_user.joined_room?(@chat_room)
      render js: "alert(이미 입장한 방입니다.)" 
    else
      @chat_room.user_admit_room(current_user)
    end
  end
  
  def chat
    # 기본적으로 chat_room.id가 chats에 들어가 있음
    @chat_room.chats.create(user_id: current_user.id, message: params[:message])
  end

  def user_exit_room
    # chat_room의 인스턴스 메소드로 사용될 예정
    @chat_room.user_exit_room(current_user)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_chat_room
      @chat_room = ChatRoom.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def chat_room_params
      params.fetch(:chat_room, {}).permit(:title, :max_count)
    end
end
