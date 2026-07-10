FROM ruby:3.3-alpine

RUN apk add --no-cache build-base

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 4000

CMD ["bundle", "exec", "puma", "-p", "4000", "-b", "0.0.0.0"]
