require "rails_helper"

# The bulk reminder page keeps every emailable registrant in the list and uses
# the filters only to decide who stays checked. These specs lock in that
# "filter checks, never hides" behaviour and the turbo-frame auto-refresh.
RSpec.describe "Events::BulkReminders", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 10_000) }
  let!(:jane) { create(:event_registration, event: event, registrant: create(:person, first_name: "Jane", last_name: "Adams")) }
  let!(:sam) { create(:event_registration, event: event, registrant: create(:person, first_name: "Sam", last_name: "Cole")) }

  before { sign_in admin }

  def checked?(body, registration)
    node = Nokogiri::HTML(body).at_css("#registration_ids_#{registration.id}")
    node.present? && node["checked"].present?
  end

  # A bulk-payment submission for this event whose single attendee isn't
  # registered, so it qualifies for the Pay-for-Others reminder section.
  def bulk_submission_with_unregistered_attendee(payer_name: "Pat Payer")
    form = create(:form)
    first, last = payer_name.split
    payer = create(:person, first_name: first, last_name: last)
    submission = create(:form_submission, form: form, event: event, person: payer, role: "bulk_payment")
    field = create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees")
    submission.form_answers.create!(form_field: field,
                                    submitted_answer: [ { "first_name" => "Nora", "last_name" => "West" } ].to_json)
    submission
  end

  it "checks every registrant by default" do
    get preview_reminder_event_path(event)

    expect(response).to have_http_status(:ok)
    expect(checked?(response.body, jane)).to be(true)
    expect(checked?(response.body, sam)).to be(true)
  end

  it "keeps all registrants visible but only checks the matches when filtered" do
    get preview_reminder_event_path(event, name: "jane"),
        headers: { "Turbo-Frame" => "reminder_recipients" }

    expect(response).to have_http_status(:ok)
    # Both rows still render...
    expect(response.body).to include("Jane Adams")
    expect(response.body).to include("Sam Cole")
    # ...but only the matching registrant stays checked.
    expect(checked?(response.body, jane)).to be(true)
    expect(checked?(response.body, sam)).to be(false)
  end

  describe "confirm interstitial" do
    it "lists the selected recipients and the message preview without sending yet" do
      expect {
        post confirm_reminder_event_path(event), params: { registration_ids: [ jane.id ], custom_message: "See you soon!" }
      }.not_to change(Notification, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane Adams")
      expect(response.body).not_to include("Sam Cole")
      # Subject line and the composed message are shown on the interstitial.
      expect(response.body).to include("Reminder: #{event.title}")
      expect(response.body).to include("See you soon!")
      # The selection + composed content carry forward as hidden fields.
      expect(response.body).to include("value=\"#{jane.id}\"")
    end

    it "redirects back to the picker when nothing is selected" do
      post confirm_reminder_event_path(event), params: { registration_ids: [] }

      expect(response).to redirect_to(preview_reminder_event_path(event, custom_message: "", custom_subject: ""))
      expect(flash[:alert]).to be_present
    end
  end

  describe "editing a registration from the picker" do
    # Opens in a new tab so the in-progress subject/message draft on the picker
    # isn't lost; the picker page stays put while the registration is edited.
    it "opens each registration edit in a new tab" do
      get preview_reminder_event_path(event),
          headers: { "Turbo-Frame" => "reminder_recipients" }

      link = Nokogiri::HTML(response.body)
        .at_css("a[href*='#{edit_event_registration_path(jane)}']")
      expect(link).to be_present
      expect(link["target"]).to eq("_blank")
      expect(link["href"]).to include("return_to=preview_reminder")
    end

    it "returns to the picker after save" do
      patch event_registration_path(jane),
            params: { return_to: "preview_reminder", event_registration: { intends_to_pay: "1" } }

      expect(response).to redirect_to(preview_reminder_event_path(event))
    end
  end

  describe "sending" do
    it "creates one reminder notification per selected registrant and one admin FYI" do
      expect {
        post send_reminder_event_path(event), params: { registration_ids: [ jane.id, sam.id ], custom_message: "See you soon!" }
      }.to change { Notification.where(kind: "event_registration_reminder").count }.by(2)
        .and have_enqueued_mail(EventMailer, :event_registration_reminder_fyi).once

      expect(response).to redirect_to(registrants_event_path(event))
    end
  end

  describe "Pay for Others submitters" do
    let!(:submission) { bulk_submission_with_unregistered_attendee }

    it "lists a qualifying submitter, pre-checked, below the registrants" do
      get preview_reminder_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pay for Others submitters")
      expect(response.body).to include("Pat Payer")
      node = Nokogiri::HTML(response.body).at_css("#form_submission_ids_#{submission.id}")
      expect(node).to be_present
      expect(node["checked"]).to be_present
    end

    it "omits a submitter whose attendees are all registered and paid" do
      registrant = create(:person, first_name: "Nora", last_name: "West")
      reg = create(:event_registration, event: event, registrant: registrant)
      create(:allocation, allocatable: reg, amount: event.cost_cents)

      get preview_reminder_event_path(event)

      expect(response.body).not_to include("Pat Payer")
    end

    it "lists the submitter on the confirm interstitial without sending" do
      expect {
        post confirm_reminder_event_path(event), params: { form_submission_ids: [ submission.id ], custom_message: "Please pay!" }
      }.not_to change(Notification, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pat Payer")
      expect(response.body).to include("value=\"#{submission.id}\"")
    end

    it "sends a bulk-payment reminder notification to a selected submitter" do
      expect {
        post send_reminder_event_path(event), params: { registration_ids: [ jane.id ], form_submission_ids: [ submission.id ] }
      }.to change { Notification.where(kind: "event_registration_reminder").count }.by(1)
        .and change { Notification.where(kind: "event_bulk_payment_reminder").count }.by(1)
        .and have_enqueued_mail(EventMailer, :event_registration_reminder_fyi).once

      expect(response).to redirect_to(registrants_event_path(event))
    end

    it "can send to a submitter alone" do
      expect {
        post send_reminder_event_path(event), params: { form_submission_ids: [ submission.id ] }
      }.to change { Notification.where(kind: "event_bulk_payment_reminder").count }.by(1)

      expect(response).to redirect_to(registrants_event_path(event))
    end
  end
end
