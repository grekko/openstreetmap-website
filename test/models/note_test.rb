require "test_helper"

class NoteTest < ActiveSupport::TestCase
  def test_status_valid
    ok = %w[open closed hidden]
    bad = %w[expropriated fubared]

    ok.each do |status|
      note = create(:note)
      note.status = status
      assert_predicate note, :valid?, "#{status} is invalid, when it should be"
    end

    bad.each do |status|
      note = create(:note)
      note.status = status
      assert_not note.valid?, "#{status} is valid when it shouldn't be"
    end
  end

  def test_body_valid
    ok = %W[Name vergrößern foo\nbar
            ルシステムにも対応します 輕觸搖晃的遊戲]
    bad = ["foo\x00bar", "foo\x08bar", "foo\x1fbar", "foo\x7fbar",
           "foo\ufffebar", "foo\uffffbar"]

    ok.each do |body|
      note = build(:note, :body => body)
      assert_predicate note, :valid?, "#{body} is invalid, when it should be"
    end

    bad.each do |body|
      note = build(:note, :body => body)
      assert_not note.valid?, "#{body} is valid when it shouldn't be"
    end
  end

  def test_close
    note = create(:note)
    assert_equal "open", note.status
    assert_nil note.closed_at
    note.close
    assert_equal "closed", note.status
    assert_not_nil note.closed_at
  end

  def test_reopen
    note = create(:note, :status => "closed", :closed_at => Time.now.utc)
    assert_equal "closed", note.status
    assert_not_nil note.closed_at
    note.reopen
    assert_equal "open", note.status
    assert_nil note.closed_at
  end

  def test_visible?
    assert_predicate create(:note, :status => "open"), :visible?
    assert_predicate create(:note, :status => "closed"), :visible?
    assert_not create(:note, :status => "hidden").visible?
  end

  def test_closed?
    assert_predicate create(:note, :status => "closed", :closed_at => Time.now.utc), :closed?
    assert_not create(:note, :status => "open", :closed_at => nil).closed?
  end

  # FIXME: notes_refactoring
  def test_author_remove_after_notes_refactoring_is_completed
    comment = create(:note_comment, :opened)
    assert_nil comment.note.author

    user = create(:user)
    comment = create(:note_comment, :opened, :author => user)
    assert_equal user, comment.note.author
  end

  def test_author
    note = create(:note)
    assert_nil note.author

    user = create(:user)
    note = create(:note, :author => user)
    assert_equal user, note.author
  end

  # FIXME: notes_refactoring
  def test_author_ip_remove_after_notes_refactoring_is_completed
    comment = create(:note_comment, :opened)
    assert_nil comment.note.author_ip

    comment = create(:note_comment, :opened, :author_ip => IPAddr.new("192.168.1.1"))
    assert_equal IPAddr.new("192.168.1.1"), comment.note.author_ip
  end

  def test_author_ip
    note = create(:note)
    assert_nil note.author_ip

    note = create(:note, :author_ip => IPAddr.new("192.168.1.1"))
    assert_equal IPAddr.new("192.168.1.1"), note.author_ip
  end

  # Ensure the lat/lon is formatted as a decimal e.g. not 4.0e-05
  def test_lat_lon_format
    note = build(:note, :latitude => 0.00004 * GeoRecord::SCALE, :longitude => 0.00008 * GeoRecord::SCALE)

    assert_equal "0.0000400", note.lat.to_s
    assert_equal "0.0000800", note.lon.to_s
  end
end
