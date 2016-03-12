# This is a sample app for Rails's GSoC project: Eager Load Action View Templates

## Setup

- Clone the project
- Run migrations

## Try it out

- Start server, and during initialization you will see something like:

```
# I monkey-patched the `compile!` method in `ActionView::Template` so it prints out these lines
# numbers indicate template's object_id
# the boolean shows that the template is not compiled yet
Is (70201687708620) compiled? false
Is (70201678855860) compiled? false
Is (70201678851900) compiled? false
Is (70201678848340) compiled? false
Is (70201687692700) compiled? false
Is (70201687689420) compiled? false
Is (70201678838020) compiled? false
Is (70201678834060) compiled? false
```

- Visit `posts` and `users`'s resouces paths like `localhost:3000/posts` or `localhost:3000/users`. And you will see:

```
# template 70201687692700 (posts/index) already compiled during initialization
# so it returns true here
Is (70201687692700) compiled? true
  Post Load (1.4ms)  SELECT "posts".* FROM "posts"
  Rendered posts/index.html.erb within layouts/application (5.6ms)
# because I haven't find a way to find layouts/application correctly, it was not compiled until now
Is (70201713690000) compiled? false
```


## Problems need to be solved

- I haven't figured out the best way to get all templates.
- How we create the `details` argument in `step-3` will determine the cache is useful or useless. In the sample app, I just use the most common value as a fixed value.
