# Day 21. 실시간 채팅방 구현_2





where( ) --> return 값이 association 값이 들어가 있음 빈 배열이 디폴트 값으로 가지고 있음

where( ).lenth > 0 무조건 false 



*Day20에서 발생한 문제점*

- 1번 채팅방에서 남긴 대화들이 2번 채팅방에서 등장함
- 



### remote: true

ajax 코드를 생략하고 remote를 통해 값을 전달할 수 있음

해당 패스로 데이터를 넘겨 줌





*app/models/admission.rb*

```ruby
class Admission < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room, counter_cache: true
    
    after_commit :user_join_chat_room_notification, on: :create
    
    def user_join_chat_room_notification
        # 'chat_room'이란 채널에 'join' 이벤트 발생
        Pusher.trigger("chat_room_#{self.chat_room_id}", 'join', {chat_room_id: self.chat_room_id, email: self.user.email}.as_json)
    end
    
end
```



## 채팅 입력시 바로 chat-list에 append 하기



*app/models/chat.rb*

```ruby

```





*app/views/show.html.erb*

```erb

```





## 로그인이 안된 상태에서는 채팅방의 내용이 보여서는 안돼





### 방 나가기

- 채팅방에 참여한 사람 리스트에서 삭제
- OO님이 나가셨습니다. 가 채팅방에 적혀 나오기



### channel에 데이터 추가해서 보내기 : .merge

*$ rails c*

```command

```





contorller 에 의해 commit이 실행된 후 

model의 메소드가 실행되는데 

이때 pusher.trigger을 통해 외부의 Pusher가 동작하면서

---------- 클라이언트 단 ----------------

Pusher.subscirbe(리스너) 가 동작 해서 이 때 언급한 채널에

data를 보내는데 특정 이벤트와 bind 함



*ajax와 비교해보기*

client의 요청을 server에서 받아서 js.erb라는 실행파일을 나에게만 보여줌

Pusher는 js.erb라는 실행파일을 해당 공간에 있는 모든 사람에게 보내준다고 생각하기





> Todays' error
>
> - 오타
>   - $('.chat_list').append(`<p>${data.user_id}: ${data.message}<small>(${data.created_at})</small></p>`)}   -->  $(' ')   / $(document)



client에서 방을 생성해달라고 요청을 보내면 서버에서 controller 실행하고 model method가 실행되고, subscribe 하니까 데이터를 싣고 해당 채널로

데이터를 보내줌

show단에서 해당 이름의 채널이 데이터를 받아서, 여기서 function으로 메소드를 실행함 

index단에서 해당 이름의 채널이 데이터를 받아서, 여기서  function으로 메소드를 실행해야해





## 과제

1. 현재 메인페이지(index)에서 방을 만들었을 때 참석 인원이 0명인 상태. 어제처럼 1로 증가하게 만들기
   - 방을 생성하면 index창에 새로 만든 방이 뜨는데, 인원 수가 0이니까 1로 보이게 만들어주기
   - 바로 화면에서 새로고침없이 변경되도록 만들어야해 
   - 

2. 방제 수정/삭제하는 경우에 index에서 적용(Puser)가 될 수 있도록

   - 수정

     - `show`에서 수정 버튼을 누르면 `routes`에 의해 ` /chat_rooms/:id/edit(.:format) =>  chat_rooms#edit`, `conttroller`의 해당 액션이 실행됨 *edit*, *update*가 실행됨

   - 삭제

     - `show`에서 채팅방 삭제 버튼을 누르면 `routes`에 의해  `chat_room`  `DELETE /chat_rooms/:id(.:format) => chat_rooms#destroy` 실행됨

     - `controller`가 실행되고 commit한 후에 `model`에서 정의해 준 `method`가 작동함

       *app/models/chat_room.rb*

       ```ruby
       after_commit :destroy_chat_room_notification, on: :delete
       ```

       

     - `Pusher.trigger`을 통해 해당 채널에 데이터를 실어서 보내주면서 `delete`이벤드가 실행된다.

       *app/models/chat_room.rb*

       ```erb
       def destroy_chat_room_notification
          Pusher.trigger('chat_room', 'delete', self.as_json)
       end
       ```

       

     - *index.html.erb*에서 js가 실행되면서 해당 이벤트에 맞는 function을 실행시킨다.

       *app/views/index.html.erb*

       ```erb
       function room_deleted(data) {
           $(`.room${data.id}`).remove();
         }
       
       channel.bind('delete', function(data) {
             room_deleted(data);
       })
       ```

     - 단, 채팅방의`master_id`만이 방을 삭제할 수 있다

       *app/controller/chat_rooms_controller*

       ```ruby
       def destroy
           if @chat_room.master_id.eql? (current_user.email)
             @chat_room.destroy
             respond_to do |format|
                format.html { redirect_to chat_rooms_url, notice: 'Chat room was successfully destroyed.' }
                format.json { head :no_content }
             end
           else
             render js: "alert(방장 외에는 방을 삭제할 수 없습니다.)"
           end
         end
       ```

       

3. 방을 나왔을 때, 이 방의 인원을 -1 해주기 (index에서 보여주기)

   - 앞서 구현한 *chat_room.rb*에서 `user_exit_room` 메소드가 발생하며 리스트에서 해당 유저 정보를 삭제함

   - 또한 *admission.rb*에서 user와 chat_room의 연결고리로 퇴장한 유저의 admission 끈을 끊어야함

   - 유저가 퇴장했을 때(해당 user의 admission이 사라졌을 때) 채팅방에 현재 남아 있는 유저 수가 실시간으로 반영됨

     *app/models/admission.rb*

     ```ruby
     def user_exit_chat_room_notification
        Pusher.trigger("chat_room_#{self.chat_room_id}", 'exit', self.as_json.merge({email: self.user.email}))
        Pusher.trigger("chat_room", 'minusone', self.as_json)
     end
     ```

     - `Pusher`을 추가해서 현재 참여중인 인원수에 실시간으로 반영되도록 설정
     - *index*에서 보여지는 채팅방의 현재 참여 인원수 정보는 `chat_room` 채널에 담겨있기 때문에 이를 호출한다.

     *app/views/index.html.erb*

     ```erb
     function user_exit(data) {
         var current = $(`.current${data.chat_room_id}`);
         current.text(parseInt(current.text()) - 1);
     }
     
     channel.bind('minusone', function(data) {
           user_exit(data);
     })
     ```

     