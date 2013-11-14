import json

from social.tests.backends.oauth import OAuth2Test


class HhruOAuth2Test(OAuth2Test):
    backend_path = 'social.backends.hhru.HhruOAuth2'
    user_data_url = 'https://api.hh.ru/me'
    expected_username = 'hhru_foo_1111'
    access_token_body = json.dumps({
        "access_token": "ACCESS_TOKEN",
        "token_type": "bearer",
        "refresh_token": "REFRESH_TOKEN",
        "expires_in": 1209600
    })
    user_data_body = json.dumps({
        'id': 1111,
        'email': 'foo@bar.bar',
        'first_name': 'Foo',
        'last_name': 'Bar',
        'is_employer': True,
        'employer': {
            'id': 9999,
            'name': 'Foo',
            'manager_id': 99999999,
        },
    })

    def test_login(self):
        self.do_login()

    def test_partial_pipeline(self):
        self.do_partial_pipeline()
