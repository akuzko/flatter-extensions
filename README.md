# Flatter::Extensions

[![Build Status](https://secure.travis-ci.org/akuzko/flatter-extensions.png)](http://travis-ci.org/akuzko/flatter-extensions)

A set of extensions to be used with [Flatter](https://github.com/akuzko/flatter) gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'flatter-extensions'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install flatter-extensions

## Usage

All extensions can be included at a runtime using `Flatter.use` method. Usually,
this is done in your app initializer with a `Flatter.configure`, like so:

```ruby
Flatter.configure do |f|
  f.use :order
  f.use :skipping
  f.use :active_record
end
```

Bellow is a list of available extensions with description.

### Multiparam

```ruby
Flatter.use :multiparam
```

Allows you to define multiparam mappings by using `:multiparam` option to mapping.
Works pretty much like `Rails` multiparam attribute assignment:

```ruby
class PersonMapper < Flatter::Mapper
  map :first_name, :last_name
  map dob: :date_of_birth, multiparam: Date
end

# ...

mapper = PersonMapper.new(person)
mapper.write(first_name: 'John', 'dob(1i)' => '2015', 'dob(2i)' => '01', 'dob(3i)' => '15')
person.date_of_birth # => Thu, 15 Jan 2015
```

### Skipping

```ruby
Flatter.use :skipping
```

Allows to skip mappers (mountings) from the processing chain by calling `skip!`
method on a particular mapper. This is usually used in before callbacks to
avoid processing specific mappers if they fail to match some processing condition.
For example:

```ruby
class Person < ActiveRecord::Base
  has_many :phones
end

class PhoneMapper < Flatter::Mapper
  map phone_number: :number

  validates_presence_of :phone_number
end

class PersonMapper < Flatter::Mapper
  mount :phone, foreign_key: :person_id

  set_callback :validate, :before, :skip_empty_phone

  def skip_empty_phone
    # avoids validation and creation of new phone number
    # if provided `phone_number` field was blank.
    mounting(:phone).skip! if phone_number.blank?
  end
end
```

Starting from version `0.2.1`, there are `:skip_if` and `:reject_if` options
for mounted mappers. First one is used for skipping mounting if passed condition
is evaluated to non-falsy value. Second one is used to reject specific sets of
params before they are passed for collection processing.

```ruby
class EmployeeMapper < Flatter::Mapper
  map :first_name, :last_name

  mount :department, skip_if: -> { department_name.blank? }
  mount :projects, reject_if: ->(params){ params[:project_name].blank? }
end
```

### Order

```ruby
Flatter.use :order
```

Allows you to manually control processing order of mappers and their mountings.
Provides `:index` option for mountings, which can be either a Number, which means
order for both validation and saving routines, or a hash like `{validate: -1, save: 2}`.
By default all mappers have index of `0` and processed from top to bottom.

This extension will be very handy when using with `:active_record` extension, since
all targets (records) are saved **without** callbacks and validation, which means
you won't have such things as associations autosave. That means that to properly
save records with foreign key dependencies, you have to do it in proper order.
For example, in following scenario we use `PersonMapper` to manage people. If
additionally `email` was supplied, `User` record will be created, and `Person`
record will be associated with it. This means that we need to skip User *before*
validation if there was no email provided, but save it *before* person mounter.

```ruby
class Person < ActiveRecord::Base
  belongs_to :user
end

class User < ActiveRecord::Base
  has_one :person
end

class UserMapper < Flatter::Mapper
  map :email

  validates_presence_of :email
end

class PersonMapper < Flatter::Mapper
  trait :management do
    mount :user, index: {save: -1}, mounter_foreign_key: :user_id

    set_callback :validate, :before, :skip_user

    def skip_user
      mounting(:user).skip! if email.blank?
    end
  end
end
```

### ActiveRecord

```ruby
Flatter.use :active_record
```

Probably, the most important extension, the reason why Flatter (former FlatMap)
was initially built. This extension allows you to build mappers that will handle
complexity of ActiveRecord associations in a graph of related records to provide a
single mapper object with plain hash of attributes that can be used to render a form,
used as a form object itself to distribute form params among records, or used in
your API, encapsulating processing logic with reusable traits.

When using `:active_record` extension, you should keep in mind following things:

#### Mounted target from association

If mapper's target is an `ActiveRecord::Base` object, target for mounted mappers
will be tried to be derived from relevant association. For example:

```ruby
class Person < ActiveRecord::Base
  belongs_to :user
  has_one :location
  has_many :notes
  has_many :phones
end

class PersonMapper < Flatter::Mapper
  mount :user
  mount :location
  mount :note
  mount :phones
end
```

Here we have:
- `:user` is a `:belongs_to` association. Target for mounted `UserMapper` will
  be by default fetched as `person.user || person.build_user`.

- `:location` is a `:has_one` association. Just like `:user`, target for mounted
  `LocationMapper` will be fetched as `person.location || person.build_location`.

- `:notes` is a `:has_many` association, and we map **singular** note. In this
  case target for `PhoneMapper` is fetched as `person.notes.build`. Thus, you may
  want to `skip!` this mounting before save or validation to prevent creating
  freshly-built record, if it was not populated with any values.

- `:phones` is a `:has_many` association, mounted as a collection mountings `:phones`.
  In this case whole association would handled by mapper as a collection (this
  feature is available starting from `0.2.0` version of `flatter`). Thus, reading
  instance of `PersonMapper` will give you array of `phones`, each of which will
  have it's own `key` value dependent on it's definition. See
  [flatter Collections](https://github.com/akuzko/flatter#collections) for more
  details on how mapped collections are handled.

Mounting collection associations and working with them as with collections is
not supported for now.

Keep in mind that you can always pass `:target` option to control targets of
mounted mappers.

#### Saving is performed without validation and callbacks by default

On save your models will not be validated (and their validation callbacks will
not be called), and their `:save` callbacks will not be executed. However,
starting from version `0.2.1`, you can use `Flatter::Mapper` class-level methods
`enable_callback` (and it's alias `enable_callbacks`) to enable specific
callbacks, such as `enable_callbacks :create, :update`.

For example, if you have multi-step form and want to put all your validations in
model, there will be dozens of boolean checks to use specific validations only
on specific steps. With mappers, you can define necessary sets of validations
within traits and keep your models clean.

#### Processing order and foreign keys

Since there are no callbacks, there will be no association autosaving, which means
that your models will be saved exactly once exactly when each mapper starts it's
saving routines. That also means that you should manually handle foreign keys
assigning when creating new records. This can be done via before- or after-save
callbacks, but extension provides a handy mounting options to do it for you:
`foreign_key` and `mounter_foreign_key`. First option should be set when mounted
mapper depends on current one. And the second one - when current mapper depends on
mounted one. In that case `:index` option should be used to force this mounting
to be processed first:

```ruby
class PersonMapper < Flatter::Mapper
  mount :user, mounter_foreign_key: :user_id, index: -1
  mount :phone, foreign_key: :person_id
end
```

#### Transactions

With `:active_record` extension you should mainly use `apply(params)` method for
updating or creating your models via mappers. It wraps whole saving process (writing
values, validation and saving) in a transaction. The reason for this is that your
mappings may have custom db-mutating writers, and if saving fails, such mutations
should be rolled back. However, `save` method is also wrapped in transaction and
will return `false` if any mapper in processing chain will fail to save it's
target. This might happen due to DB constraints, for example.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/akuzko/flatter-extensions.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

