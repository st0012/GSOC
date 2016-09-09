# This is a sample app for Rails' Eager Loading Action View Templates

## Setup

- Clone the project
- Run migrations

## Try it out

- Start server, and during initialization you will see something like:

```
# I monkey-patched the `compile!` method in `ActionView::Template` so it prints out these lines
Is (app/views/layouts/application.html.erb) compiled? false
Is (app/views/posts/_form.html.erb) compiled? false
Is (app/views/posts/edit.html.erb) compiled? false
Is (app/views/posts/index.html.erb) compiled? false
Is (app/views/posts/new.html.erb) compiled? false
Is (app/views/posts/show.html.erb) compiled? false
Is (app/views/users/_form.html.erb) compiled? false
Is (app/views/users/edit.html.erb) compiled? false
Is (app/views/users/index.html.erb) compiled? false
Is (app/views/users/new.html.erb) compiled? false
Is (app/views/users/show.html.erb) compiled? false
```

- Visit `posts`'s resouces paths like `localhost:3000/posts`. And you will see:

```
Processing by PostsController#index as HTML
Is (app/views/posts/index.html.erb) compiled? true
  Post Load (0.2ms)  SELECT "posts".* FROM "posts"
  Rendered posts/index.html.erb within layouts/application (2.8ms)
Is (app/views/layouts/application.html.erb) compiled? true
Completed 200 OK in 29ms (Views: 27.8ms | ActiveRecord: 0.2ms)
```
## My approaches to implement this feature

Before I describe my approaches, there are some facts related to our goal:

- A `resolver` is an object responsible for finding templates under certain view path, like `"#{Rails.application.roote}/app/views"`.
- A `PathSet` instance contains several resolvers and will be stored in `ActionView::Base`'s class variable. This means that once the app is initialized, every request shares same sets of resolvers.
- The resolver we use to find templates (normally is `OptimizedFileSystemResolver`) will cache the template objects it found.
- Every template object caches its compiled result.

And here's what I am going to do:

#### 1. Find all template paths
Get all the template paths and get their `name (usually action)` and `prefix (normally controller)`. And for now, there are two approaches doing this.

- Inspect every files' path in the `app/views` folder.
- Inspect application's routes, which is very convenient for getting their `name` and `prefix`.

~~I think the second approach might be better than the first one. But I can't get some templates' path using this way, like `layouts/application.html.erb` since there won't be any route for it.~~

**Update**: After some experiments, I think it would be better to use the first approach. Because it's very difficult to find layouts or partials through routes.

#### 2. Create `PathSet` instance and resolvers

First, I need to initialize resolvers with every view paths I have. And then I use an array which contains all the resolvers to initialize a `PathSet`.

Pseudo code:

```
resolvers = view_paths.map do |view_path|
  ActionView::OptimizedFileSystemResolver.new(view_path)
end

path_set = ActionView::PathSet.new(resolvers)
```


#### 3. Find templates using given paths

I will use paths I got from the previous step to find all templates.  And I think this is the core step of this project.

To find a template using resolver's `find_all` method (which will do the cache), we need to provide `6` arguments:

- name: A `string`, normally is same as the action's name which uses this template.
- prefix: A `string`, normally is same as the controller's name that renders this template.
- partial: A `boolean` which indicates that if the template is a partial.
- details: A `hash` that contains information that helps us to find the template, such as `locale`, `formats`, `variants`, `handlers`.
- details_key: An `ActionView::LookupContext::DetailsKey` instance that is used as the cache key for the resolver. And this key is shared between the same format combination, so every detail which's format is `html` will using the same key.
- locals: An `array` that contains local variables which will be passed to the view.

I think the key point in this part is how we generate the `details`, especially the `formats` part. Becuase we use it to generate cache key, the template cache will not be used if we use wrong formats in the precompile process.

#### 4. Compile all the templates we found

This step is relatively easy. All we need to do is to compile every templates we found.

#### 5. Store result into the app

As I said before, template caches its compiled result, and resolver caches templates it found while all resolvers will be stored in an instance of `ActionView::PathSet`. So in this step I need to assign the path set I created in `step 2` into `ActionController::Base` so the whole application can use the cached result.


## Problems need to be solved

- I haven't figured out the best way to get all templates.
- How we create the `details` argument in `step-3` will determine the cache is useful or useless. In the sample app, I just use the most common value as a fixed value.
