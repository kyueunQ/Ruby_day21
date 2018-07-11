class ChatRoom < ApplicationRecord
    has_many :admissions
    has_many :users, through: :admissions
    
    has_many :chats
    
    
    after_commit :create_chat_room_notification, on: :create
    after_commit :update_chat_room_notification, on: :update
    
    def create_chat_room_notification
        Pusher.trigger('chat_room', 'create', self.as_json)
    end
    
    def update_chat_room_notification
        Pusher.trigger('chat_room', 'update', self.as_json)
    end
    
    # instance method, class method (X)
    def user_admit_room(user)
        # ChatRoom이 하나 만들어 지고 나면 다음 메소드를 같이 실행한다.
        Admission.create(user_id: user.id, chat_room_id: self.id)
        
    end
    
    def user_exit_room(user)
        Admission.where(user_id: user.id, chat_room_id: self.id)[0].destroy
    end
    
end
