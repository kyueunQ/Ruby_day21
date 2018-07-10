# Day 20. 실시간 채팅방 구현

## 

`rails _5.0.7_ new chat_app`  새로운 프로젝트 생성

<br>

### 1. Gemfile 설치 및 controller와 modle 구축하기

*Gemfile*

```ruby
# Pusher 
gem 'pusher'

# authentication
gem 'devise'

# key encrypt
gem 'figaro'
```

- `$ rails g devise:install`
- `$ rails g devise users`  :  rails에서 알아서 단수형으로 변경시켜줌
- ` $ rails g scaffold chat_room` 
- `$ rails g model chat`, `$ rails g model admission`

<br><br>

### 2. DB 관계 설정하기

- `user` : `chat_room` (N:M)
  - join table  (admission.rb)
- `user`: `chat` (1:N)
- `chat_room`:`chats` (1:N)

<br>

*app/models/chat_room.rb*

```ruby
class ChatRoom < ApplicationRecord
    has_many :admissions
    has_many :users, through: :admissions
    
    has_many :chats
    ...
 end
```

*app/models/admission.rb*

```ruby
class Admission < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room, counter_cache: true
end
```

*app/models/chat.rb*

```ruby
class Chat < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room
end
```

*app/models/user.rb*

```ruby
class User < ApplicationRecord
    ...
  has_many :admissions
  has_many :chat_rooms, through: :admissions
  has_many :chats
end
```

*$ rails c를 활용해 db가 잘 구축됐는지 확인하기*

```cmd
> User.create(email:"abc@gmail.com, password:"123456", password_confirmation:"123456")

> ChatRoom.create(title:"hi", master_id:1, max_count:5)

> u = User.first
> c = ChatRoom.first

> Admission.create(user_id:u.id, chat_room_id:c.id)

// query문이 1번 
> ChatRoom.first.admissions.size
  ChatRoom Load (0.2ms)  SELECT  "chat_rooms".* FROM "chat_rooms" ORDER BY "chat_rooms"."id" ASC LIMIT ?  [["LIMIT", 1]]
 => 1 

// quer문이 2번
> ChatRoom.first.admissions.count
  ChatRoom Load (0.3ms)  SELECT  "chat_rooms".* FROM "chat_rooms" ORDER BY "chat_rooms"."id" ASC LIMIT ?  [["LIMIT", 1]]
   (0.2ms)  SELECT COUNT(*) FROM "admissions" WHERE "admissions"."chat_room_id" = ?  [["chat_room_id", 1]]
 => 1 
```

- size와 count는 동일한 기능을 하는데 size의 경우 쿼리문이 1번만 작동되어 구현함

<br>

<br>

## 3. Pusher 

- 'Pusher' 회원가입
- 'create app' 하기  (front: jquery, back: rails)  →  인증키 등 여러가지 정보가 뜸

<br>

*config/application.yml*

```command
development:
    pusher_app_id: #
    pusher_key: #
    pusher_secret: #
    pusher_cluster: #
```

- Pusher 페이지에서 인증키 등의 정보를 입력하기

<br>

*config/initializers*/pusher.rb

```ruby
require 'pusher'

Pusher.app_id = ENV["pusher_app_id"]
Pusher.key = ENV["pusher_key"]
Pusher.secret = ENV["pusher_secret"]
Pusher.cluster = ENV["pusher_cluster"]
Pusher.logger = Rails.logger
Pusher.encrypted = true
```

<br>

*app/views/layouts/apllication.html.erb*

```erb
<!DOCTYPE html>
<html>
  <head>
   ...   
    <%= stylesheet_link_tag    'application', media: 'all' %>
    <%= javascript_include_tag 'application'%>
    <script src="https://js.pusher.com/4.1/pusher.min.js"></script>
  </head>
```

- 해당 위치에 `<script src="https://js.pusher.com/4.1/pusher.min.js"></script>` 추가

<br>

<br>

### Pusher 동작 순서

### (1) 새로운 채팅방 만들기

1. user가 index에서 'New Chat room' 버튼을 클릭함 → routes를 통해 `chat_rooms#new`, `chat_rooms#create`  → 새로운 채팅방이 생성됨
2. `controller`가 작동함

*app/controller/chat_rooms_controller*

```ruby
...
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
...
```

- `current_user`은 `model` 단까지 넘어오지 않기 때문에, 모델이 `user_admit_room(user)` 메소드를 미리 정의한 후 이를 controller에서 호출해 `current_user`값을 모델로 넘겨줌 

  <br>

3. `model`에 작성해둔 코드가 작동됨

*models/chat_room.rb* : 채팅방이 생성되기까지

```ruby
class ChatRoom < ApplicationRecord
    ...
    after_commit :create_chat_room_notification, on: :create
    
    def create_chat_room_notification
        Pusher.trigger('chat_room', 'create', self.as_json)
    end
    
    # instance method, class method (X)
    def user_admit_room(user)
        # ChatRoom이 하나 만들어 지고 나면 다음 메소드를 같이 실행한다.
        Admission.create(user_id: user.id, chat_room_id: self.id)
    end  
end
```

- `on: create` '채팅방이' 생성될 때 `create_chat_room_notification`가 동작 됨
- `chat_room`이라는 채널에 `chat_room` db에 들어온 데이터를 josn 형식으로 보내는데, `create`이라는 이벤트를 실행할 것
- `on` 은 `CRUD`에 해당하는 action만 넣을 수 있음

*modelsl/admission.rb*  :  채팅방을 만든 사람이 채팅방에 속하는 과정

```ruby
class Admission < ApplicationRecord
   ...
    after_commit :user_join_chat_room_notification, on: :create
    
    def user_join_chat_room_notification
        Pusher.trigger('chat_room', 'join', {chat_room_id: self.chat_room_id, email: self.user.email}.as_json)
    end
end
```

- `on: create` '채팅방이' 생성될 때 `user_join_chat_room_notification`가 동작 됨
- `chat_room`이라는 채널에 { }안에 들어온 데이터를 josn 형식으로 보내는데, `join`이라는 이벤트를 실행할 것

<br>

4. index의 js와 ajax가 실행됨

*app/views/index.html.erb*

```erb
  <tbody class="chat_room_list">
    <% @chat_rooms.reverse.each do |chat_room| %>
      <tr>
        <td><%= chat_room.title %></td>
        <td><span class="current<%=chat_room.id%>"><%= chat_room.admissions.size %></span> / <%= chat_room.max_count %></td>
        <td><%= chat_room.master_id %></td>
        <td><%= link_to 'Show', chat_room %></td>
      </tr>
    <% end %>
  </tbody>
</table>

<br>

<%= link_to 'New Chat Room', new_chat_room_path %>

<script>
$(document).on('ready', function() {
  // 방이 만들어졌을 때 방에 대한 데이터를 받아서
  // 방 목록에 추가해주는 js funtion
    function room_created(data) {
        $('.chat_room_list').prepend(`
          <tr>
            <td>${data.title}</td>
            <td><span class="current${data.id}">0</span>/${data.max_count}</td>
            <td>${data.master_id}</td>
            <td><a href="/chat_rooms/${data.id}">Show</a></td>
          </tr>`);

     }
        
    function user_joined(data) {
      var current = $(`.current${data.chat_room_id}`);
      current.text(parseInt(current.text()) + 1);
    }
    
    // 인증정보를 넘김으로써 Pusher 인스턴스를 생성
    var pusher = new Pusher('<%= ENV["pusher_key"] %>', {
      cluster: "<%= ENV["pusher_cluster"] %>",
      encrypted: true
    });

    // 'chat_room'이라는 channel로 js방식 subscribe
    var channel = pusher.subscribe('chat_room');
    channel.bind('create', function(data) {
      console.log(data);
      room_created(data);
    });
    channel.bind('join', function(data) {
      console.log(data);
      user_joined(data);
    })
    
});
</script>
```

<Br>

<br>

#### (2) 채팅방에 join 하기

1.  `show`의 'join' 버튼을 눌렀을 때 

   ```erb
   <%= link_to 'join', join_chat_room_path(@chat_room), method: 'post', remote: true, class: "join_room" %> |
   ```

   - `join_chat_room_path` 

     :  /chat_rooms/:id/join(.:format)  => chat_rooms#user_admit_room

     <br>

2. routes를 통해 해당 controller를 실행함

   *app/controller/chat_rooms_controller*

   ```ruby
   ...
   def user_admit_room
       # 현재 유저가 있는 방에서 join 버튼을 눌렀을 때 동작하는 액션
       @chat_room.user_admit_room(current_user)
   end
   ...
   ```

   <br>

3. `model`에서 정의한 method가 호출됨 + `create` 이후 작동될 method 동작

   *app/models/chat_room.rb*

   ```ruby
   class ChatRoom < ApplicationRecord
    ...
       after_commit :create_chat_room_notification, on: :create
       
   # instance method, class method (X)
   def user_admit_room(user)
      # ChatRoom이 하나 만들어 지고 나면 다음 메소드를 같이 실행한다.
      Admission.create(user_id: user.id, chat_room_id: self.id)
   end
   ```

   *app/models/admission.rb*

   ```ruby
   class Admission < ApplicationRecord
      ...    
       after_commit :user_join_chat_room_notification, on: :create
       
       def user_join_chat_room_notification
           # 'chat_room'이란 채널에 'join' 이벤트 발생
           Pusher.trigger('chat_room', 'join', {chat_room_id: self.chat_room_id, email: self.user.email}.as_json)
       end    
   end
   ```

   - 생성됐을 때 `user_join_chat_room_notification`이 동작, `Pusher`이 발생
   - `chat_room`채널에다가 `join`이벤트가 작동할 것이며, { } 괄호 안의 데이터가 json 타입으로 넘어감

<br>

4. show의 js와 ajax가 실행됨

   *app/views/show.html.erb*

   ```erb
   <%= current_user.email %>
   <h3>현재 이 방에 참여한 사람</h3>
   <div class="join_user_list">
   <% @chat_room.users.each do |user| %>
       <p><%= user.email %></p>
   <% end %>
   </div>
   <hr>
   
   <%= link_to 'join', join_chat_room_path(@chat_room), method: 'post', remote: true, class: "join_room" %> |
   <%= link_to 'Edit', edit_chat_room_path(@chat_room) %> |
   <%= link_to 'Back', chat_rooms_path %>
   
   <script>
   $(document).on('ready', function() {
       function user_joined(data){
           $('.join_user_list').append(`<p>${data.email}</p>`);
       }
   
       var pusher = new Pusher('<%= ENV["pusher_key"] %>', {
         cluster: "<%= ENV["pusher_cluster"] %>",
         encrypted: true
       });
       
       // chat_room이라는 채널명의 join이라는 이벤트를 
       var channel = pusher.subscribe('chat_room');
       channel.bind('join', function(data) {
         console.log(data);
         user_joined(data);
       });
   })    
   </script>
   ...
   ```

<br>

<br>



### 과제

현재 이 방에 들어와 있는 사람은 join 버튼이 안보임

한 유저는 방 하나에 한번만 들어갈 수 있음