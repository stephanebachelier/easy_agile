require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe User do
  before(:each) do
    @user = User.new
  end

  it "should create a new instance given valid attributes" do
    Users.create_user!
  end

  describe "find_by_email_address_and_password" do
    def do_call
      User.find_by_email_address_and_password(@email_address, @password)
    end

    before :each do
      @email_address = 'some@ddress.com'
      @password = 'somepassword'
      @encrypted_password = 'someencryptedpassword'
      Digest::SHA1.stub!(:hexdigest).with(@password).and_return(@encrypted_password)
      User.stub!(:find_by_email_address_and_encrypted_password).
        with(@email_address, @encrypted_password).
        and_return(@user)
    end

    it "should find by email address and encrypted password" do
      User.should_receive(:find_by_email_address_and_encrypted_password).
        with(@email_address, @encrypted_password)
      do_call
    end

    it "should return the results of the find" do
      do_call.should == @user
    end
  end

  describe "associations" do
    it "should belong to an organisation" do
      User.should belong_to(:organisation)
    end

    it "should have many projects" do
      User.should have_many(:projects)
    end

    it "should belong to an organisation sponsor" do
      User.should have_many(:organisation_sponsors)
    end
  end

  describe "creation" do
    describe "for a new organisation" do
      before(:each) do
        @user = User.new(Users.user_prototype)
      end

      it "should create a new organisation for the user" do
        @user.organisation_name = 'New Organisation'
        @user.save
        Organisation.find_by_name('New Organisation').should_not be_nil
      end

      it "should encrypt the password" do
        @user.password = 'some password'
        @user.save
        @user.encrypted_password.should == Digest::SHA1.hexdigest('some password')
      end

      it "should set acknowledged to true" do
        @user.save
        @user.acknowledged?.should be_true
      end

      describe "verification token" do
        it "should be generated when a user is created" do
          @user.save
          @user.verification_token.should_not be_nil
        end

        it "should not generate the same token" do
          @user.save
          new_user = Users.create_user!
          @user.verification_token.should_not == new_user.verification_token
        end
      end
    end

    describe "for an existing organisation" do
      before :each do
        @sponsor = Users.create_user!
        @user = User.new(
          Users.user_prototype.merge(
            :sponsor => @sponsor,
            :organisation => @sponsor.organisation
          )
        )
      end

      it "should not try to encrypt the password" do
        @user.save!
        @user.encrypted_password.should be_nil
      end

      it "should set acknowledged to false" do
        @user.save!
        @user.acknowledged?.should be_false
      end
      
      describe "organisation sponsor" do
        before :each do
          @sponsor = Users.create_user!
          @organisation = Organisations.create_organisation!

          @user = User.new(
            :email_address => "sponsored_user#{User.count + 1}@jandaweb.com"
          )
          @user.organisation = @organisation
          @user.sponsor = @sponsor

          @user.save!
          @organisation_sponsor = @user.organisation_sponsors.first
        end

        it "should create an organisation sponsor" do
          @organisation_sponsor.should_not be_nil
        end

        it "should set the sponsor" do
          @organisation_sponsor.sponsor.should == @sponsor
        end

        it "should set the organisation" do
          @organisation_sponsor.organisation.should == @organisation
        end
      end

      describe "acknowledgement token" do
        before :each do
          @sponsor = Users.create_user!
          @organisation = Organisations.create_organisation!

          @user = User.new(
            :email_address => "sponsored_user#{User.count + 1}@jandaweb.com"
          )
          @user.organisation = @organisation
          @user.sponsor = @sponsor

          @user.save!
        end

        it "should be generated when a user is created" do
          @user.save
          @user.acknowledgement_token.should_not be_nil
        end

        it "should not generate the same token" do
          @user.save
          new_user = Users.create_user!(
            :sponsor => @sponsor,
            :organisation => @organisation
          )
          @user.acknowledgement_token.should_not ==
            new_user.acknowledgement_token
        end
      end

    end
  end

  describe "password=" do
    it "should have the writer" do
      User.new.should respond_to(:password=)
    end
  end

  describe "sponsor=" do
    it "should have the writer" do
      User.new.should respond_to(:sponsor=)
    end
  end

  describe "signup" do
    before :each do
      @user = User.new(Users.user_prototype)
      @sponsor = Users.create_user!
    end

    it "should be false if sponsor attribute is set" do
      @user.sponsor = @sponsor
      @user.signup?.should be_false
    end

    it "should be false if an organisation sponsor exists" do
      @user.organisation_sponsors.build(
        :sponsor_id => @sponsor.id,
        :organisation => @sponsor.organisation
      )
      @user.signup?.should be_false
    end

    it "should be true otherwise" do
      @user.signup?.should be_true
    end
  end

  describe "validations" do
    before :each do
      User.delete_all
      @user = User.new(Users.user_prototype)
    end
    
    describe "email address" do
      before :each do
        @user.email_address = nil
      end

      it "should require an email address" do
        @user.valid?
        @user.errors.invalid?(:email_address).should be_true
      end

      it "should not allow invalid email addresses" do
        @user.email_address = "this is not an email address"
        @user.valid?
        @user.errors.invalid?(:email_address).should be_true
      end

      it "should allow valid email addresses" do
        @user.email_address = "user@jandaweb.com"
        @user.valid?
        @user.errors.invalid?(:email_address).should be_false
      end

      it "should not allow duplicate email addresses" do
        email_address = "user@jandaweb.com"
        Users.create_user!(:email_address => email_address)
        @user.email_address = email_address
        @user.valid?
        @user.errors.invalid?(:email_address).should be_true
      end
    end

    describe "organisation" do
      before :each do
        @user.organisation_name = nil
        @user.organisation = nil
      end

      it "should require an organisation" do
        @user.stub!(:signup?).and_return(false)
        @user.valid?
        @user.errors.invalid?(:organisation_id).should be_true
      end

      it "should not require an organisation if organisation name is given" do
        @user.organisation_name = 'some name'
        @user.valid?
        @user.errors.invalid?(:organisation_id).should be_false
      end

      it "should not require an organisation name if organisation is given" do
        @user.organisation = Organisations.create_organisation!
        @user.valid?
        @user.errors.invalid?(:organisation_name).should be_false
      end

      it "should add an error to organisation name if both name and organisation are blank" do
        @user.valid?
        @user.errors.on(:organisation_name).should_not be_nil
      end
    end

    describe "password" do
      before :each do
        @user.password = nil
      end
      
      it "should require a password on signup" do
        @user.organisation = nil
        @user.valid?
        @user.errors.invalid?(:password).should be_true
      end

      it "should not require a password if the user is being added to an organisation" do
        @user.stub!(:signup?).and_return(false)
        @user.valid?
        @user.errors.invalid?(:password).should be_false
      end

      it "should not require a password if the encrypted password is set" do
        @user.encrypted_password = 'hashed password'
        @user.valid?
        @user.errors.invalid?(:password).should be_false
      end

      it "should require a password on update if acknowledgement_token is set" do
        @user = Users.create_user!(:acknowledgement_token => 'abcdef')
        @user.encrypted_password = ''
        @user.password = ''
        @user.valid?
        @user.errors.invalid?(:password).should be_true
      end
    end
  end

  describe "valid" do
    it "should not return users with verify_by in the past" do
      unverified_user = Users.create_user!(:verify_by => 1.day.ago)
      User.valid.should_not include(unverified_user)
    end

    it "should return users with verify_by in the future" do
      user_with_time_left = Users.create_user!(:verify_by => 1.day.from_now)
      User.valid.should include(user_with_time_left)

    end

    it "should return users with verify_by set to nil" do
      verified_user = Users.create_user!
      verified_user.update_attributes(:verify_by => nil)
      User.valid.should include(verified_user)
    end
  end

  describe "verification" do
    before :each do
      @user = Users.create_user!
    end

    it "should not be verified by default" do
      @user.verified.should be_false
    end

    it "should set verify_by on a new user" do
      @user.verify_by.should == Date.today + 7
    end

    describe "verify" do
      describe "with the correct token" do
        before :each do
          @response = @user.verify(:token => @user.verification_token)
          @user.reload
        end

        it "should return true" do
          @response.should be_true
        end

        it "should verify the user" do
          @user.should be_verified
        end

        it "should clear the verify_by date" do
          @user.verify_by.should be_nil
        end
      end

      describe "with an incorrect token" do
        before :each do
          @response = @user.verify(:token => 'wrong token')
          @user.reload
        end

        it "should return false" do
          @response.should be_false
        end

        it "should not verify the user" do
          @user.should_not be_verified
        end

        it "should not clear the verify_by date" do
          @user.verify_by.should_not be_nil
        end
      end
    end
  end

  describe "acknowledge" do
    before :each do
      @sponsor = Users.create_user!
      @user = Users.create_user!(
        :sponsor => @sponsor,
        :organisation => @sponsor.organisation
      )
    end

    describe "with valid token and password" do
      before :each do
        @password = 'some new password'
        @response = @user.acknowledge(
          :token => @user.acknowledgement_token,
          :password => @password
        )
        @user.reload
      end

      it "should set acknowledgement_token to nil" do
        @user.acknowledgement_token.should be_nil
      end

      it "should delete the organisation sponsor" do
        @user.organisation_sponsors.should be_empty
      end

      it "should update the password" do
        @user.encrypted_password.should == Digest::SHA1.hexdigest(@password)
      end

      it "should return true" do
        @response.should be_true
      end
    end

    describe "with invalid token" do
      before :each do
        @password = 'some new password'
        @response = @user.acknowledge(
          :token => 'wjiefoafew',
          :password => @password
        )
        @user.reload
      end

      it "should not set acknowledgement_token to nil" do
        @user.acknowledgement_token.should_not be_nil
      end

      it "should not delete the organisation sponsor" do
        @user.organisation_sponsors.should_not be_empty
      end

      it "should not update the password" do
        @user.encrypted_password.should be_nil
      end

      it "should return false" do
        @response.should be_false
      end
    end

    describe "with no password" do
      before :each do
        @response = @user.acknowledge(
          :token => @user.acknowledgement_token,
          :password => ''
        )
        @user.reload
      end

      it "should not set acknowledgement_token to nil" do
        @user.acknowledgement_token.should_not be_nil
      end

      it "should not delete the organisation sponsor" do
        @user.organisation_sponsors.should_not be_empty
      end

      it "should update the password" do
        @user.encrypted_password.should be_nil
      end

      it "should return false" do
        @response.should be_false
      end
    end
  end
end
