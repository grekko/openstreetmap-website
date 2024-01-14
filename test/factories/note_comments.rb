FactoryBot.define do
  factory :note_comment do
    sequence(:body) { |n| "This is note comment #{n}" }
    visible { true }
    event { "commented" }
    note

    # FIXME notes_refactoring
    trait :opened do
      event { "opened" }
    end
  end
end
